import CWaylandClientSystem
import CWaylandProtocols
import Glibc

package final class RawSharedMemory {
    package let version: RawVersion
    package let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    package var pointer: OpaquePointer { proxy.pointer }

    init(
        pointer sharedMemoryPointer: OpaquePointer,
        version sharedMemoryVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = sharedMemoryVersion
        proxyAdoption = adoptionContext
        let adoptedPointer: OpaquePointer
        do {
            adoptedPointer = try adoptionContext.adopt(sharedMemoryPointer, interface: "wl_shm")
        } catch {
            unsafe swl_shm_destroy(sharedMemoryPointer)
            throw error
        }
        proxy = RawOwnedProxy(
            pointer: adoptedPointer,
            destroy: unsafe swl_shm_destroy
        )
    }
    package func createPool(
        width: Int32,
        height: Int32,
        bufferCount: Int
    ) throws(RuntimeError) -> RawSharedMemoryPool {
        try createPool(
            width: width,
            height: height,
            bufferCount: bufferCount,
            onBufferReleased: Self.ignoreBufferRelease
        )
    }
    package func createPool(
        width: Int32,
        height: Int32,
        bufferCount: Int,
        onBufferReleased: @escaping () -> Void
    ) throws(RuntimeError) -> RawSharedMemoryPool {
        try .init(
            sharedMemory: self,
            width: width,
            height: height,
            bufferCount: bufferCount,
            onBufferReleased: onBufferReleased
        )
    }

    private static func ignoreBufferRelease() {
        // Raw clients without release notifications still reuse buffers by polling.
    }
    func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
private struct MappedRegion: ~Copyable {
    let byteCount: Int
    let baseAddress: UnsafeMutableRawPointer

    init(fileDescriptor: Int32, byteCount requestedByteCount: Int) throws(RuntimeError) {
        let mapped = unsafe mmap(
            nil,
            requestedByteCount,
            PROT_READ | PROT_WRITE,
            MAP_SHARED,
            fileDescriptor,
            0
        )

        guard let mapped, mapped != MAP_FAILED else {
            throw RuntimeError.systemError(errno: errno, operation: .mapSharedMemory)
        }

        baseAddress = mapped
        byteCount = requestedByteCount
    }

    deinit {
        unsafe munmap(baseAddress, byteCount)
    }
}

private final class SharedMemoryMapping {
    private let mappedRegion: MappedRegion

    var byteCount: Int { mappedRegion.byteCount }

    var baseAddress: UnsafeMutableRawPointer { mappedRegion.baseAddress }

    init(fileDescriptor: Int32, byteCount requestedByteCount: Int) throws(RuntimeError) {
        guard requestedByteCount > 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .validateArgument("shared memory mapping byte count"))
        }

        mappedRegion = try MappedRegion(
            fileDescriptor: fileDescriptor,
            byteCount: requestedByteCount
        )
    }
}

package struct BufferLayout: Equatable, Sendable {
    package let width: Int32
    package let height: Int32
    package let stride: Int32
    package let byteCount: Int

    package init(width bufferWidth: Int32, height bufferHeight: Int32) throws(RuntimeError) {
        guard bufferWidth > 0, bufferHeight > 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .validateArgument("buffer dimensions"))
        }

        let strideResult = Int(bufferWidth).multipliedReportingOverflow(
            by: MemoryLayout<UInt32>.stride
        )
        guard !strideResult.overflow, strideResult.partialValue <= Int(Int32.max) else {
            throw RuntimeError.systemError(
                errno: EOVERFLOW, operation: .validateArgument("buffer stride"))
        }

        let byteCountResult = strideResult.partialValue
            .multipliedReportingOverflow(by: Int(bufferHeight))
        guard !byteCountResult.overflow else {
            throw RuntimeError.systemError(
                errno: EOVERFLOW, operation: .validateArgument("buffer byte count"))
        }

        width = bufferWidth
        height = bufferHeight
        stride = Int32(strideResult.partialValue)
        byteCount = byteCountResult.partialValue
    }
}

package struct BufferBusyState: Equatable, Sendable {
    package private(set) var isBusy = false

    package init() {
        // Start reusable until the buffer is attached for presentation.
    }

    package mutating func markBusy() {
        isBusy = true
    }

    package mutating func markReleased() {
        isBusy = false
    }
}

private enum BufferReleaseInstallState {
    case idle
    case installed
}

private final class BufferReleaseOwner {
    private let invariantFailureSink: RawInvariantFailureSink?
    private var onRelease: (() -> Void)?
    private var installState = BufferReleaseInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_buffer_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_buffer_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(invariantFailureSink failureSink: RawInvariantFailureSink? = nil) {
        invariantFailureSink = failureSink

        callbacks.pointee.release = { data, _ in
            BufferReleaseOwner.withOwner(
                data,
                message: "wl_buffer release fired without Swift state"
            ) { owner in
                owner.onRelease?()
            }
        }
    }

    func install(
        on buffer: OpaquePointer,
        onRelease handler: @escaping () -> Void
    ) throws(RuntimeError) {
        guard installState == .idle else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .installListener("wl_buffer"))
        }

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_buffer_add_listener(buffer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .installListener("wl_buffer"))
        }

        onRelease = handler
        installState = .installed
    }

    func cancel() {
        onRelease = nil
        listenerStorage.invalidate()
    }

    deinit {
        cancel()
    }

    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (BufferReleaseOwner) -> Void
    ) {
        CListenerStorage<BufferReleaseOwner, swl_buffer_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

package final class RawBuffer {
    package let width: Int32
    package let height: Int32
    package let stride: Int32
    private let bytes: UnsafeMutableRawBufferPointer

    private let releaseOwner: BufferReleaseOwner
    private var proxy: RawOwnedProxy
    private var busyState = BufferBusyState()
    private var releaseObserver: (() -> Void)?

    var pointer: OpaquePointer { proxy.pointer }

    package var isBusy: Bool { busyState.isBusy }

    package func withUnsafeMutableBytes<R>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> R
    ) rethrows -> R {
        try unsafe body(bytes)
    }

    init(
        pointer bufferPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        width bufferWidth: Int32,
        height bufferHeight: Int32,
        stride bufferStride: Int32,
        bytes bufferBytes: UnsafeMutableRawBufferPointer
    ) throws(RuntimeError) {
        width = bufferWidth
        height = bufferHeight
        stride = bufferStride
        bytes = bufferBytes
        releaseOwner = BufferReleaseOwner(
            invariantFailureSink: adoptionContext.invariantFailureSink
        )
        let adoptedPointer: OpaquePointer
        do {
            adoptedPointer = try adoptionContext.adopt(bufferPointer, interface: "wl_buffer")
        } catch {
            unsafe swl_buffer_destroy(bufferPointer)
            throw error
        }
        proxy = RawOwnedProxy(
            pointer: adoptedPointer,
            destroy: unsafe swl_buffer_destroy
        )

        try releaseOwner.install(on: bufferPointer) { [weak buffer = self] in
            guard let buffer else { return }

            buffer.handleRelease()
        }
    }

    package func markBusy() {
        busyState.markBusy()
    }

    func markReleased() {
        busyState.markReleased()
    }

    func setReleaseObserver(_ observer: @escaping () -> Void) {
        releaseObserver = observer
    }

    private func handleRelease() {
        markReleased()
        releaseObserver?()
    }

    package func destroy() {
        releaseObserver = nil
        releaseOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawSharedMemoryPool {
    package let size: TopLevelSize
    package let layout: BufferLayout

    private let mapping: SharedMemoryMapping
    private let buffers: [RawBuffer]
    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    private var pointer: OpaquePointer { proxy.pointer }

    init(
        sharedMemory: RawSharedMemory,
        width: Int32,
        height: Int32,
        bufferCount: Int,
        onBufferReleased: @escaping () -> Void
    ) throws(RuntimeError) {
        guard bufferCount > 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL, operation: .validateArgument("shared memory buffer count"))
        }

        let bufferLayout = try BufferLayout(width: width, height: height)
        let totalBytes = try Self.totalByteCount(
            layout: bufferLayout,
            bufferCount: bufferCount
        )
        var fileDescriptor = try RawFileDescriptor.memfd(name: "swift-wayland-buffer-pool")
        try fileDescriptor.resize(byteCount: totalBytes)

        let memoryMapping = try SharedMemoryMapping(
            fileDescriptor: fileDescriptor.rawValue,
            byteCount: totalBytes
        )
        let poolPointer = try Self.createPool(
            sharedMemory: sharedMemory,
            fileDescriptor: fileDescriptor.rawValue,
            totalBytes: totalBytes
        )
        let adoptionContext = sharedMemory.proxyAdoption
        fileDescriptor.close()

        do {
            let createdBuffers = try Self.createBuffers(
                pool: poolPointer,
                proxyAdoption: adoptionContext,
                mapping: memoryMapping,
                layout: bufferLayout,
                count: bufferCount
            )
            for buffer in createdBuffers {
                buffer.setReleaseObserver(onBufferReleased)
            }

            buffers = createdBuffers
            size = .init(width: width, height: height)
            layout = bufferLayout
            mapping = memoryMapping
            proxyAdoption = adoptionContext
            proxy = RawOwnedProxy(
                pointer: try adoptionContext.adopt(poolPointer, interface: "wl_shm_pool"),
                destroy: unsafe swl_shm_pool_destroy
            )
        } catch {
            unsafe swl_shm_pool_destroy(poolPointer)
            throw error
        }
    }

    package func nextFreeBuffer() -> RawBuffer? {
        buffers.first { !$0.isBusy }
    }

    package var hasFreeBuffers: Bool { buffers.contains { !$0.isBusy } }

    package var hasBusyBuffers: Bool { buffers.contains(where: \.isBusy) }

    package func destroy() {
        for buffer in buffers {
            buffer.destroy()
        }
        proxy.destroy()
    }

    deinit {
        destroy()
    }

    private static func totalByteCount(
        layout: BufferLayout,
        bufferCount: Int
    ) throws(RuntimeError) -> Int {
        let totalBytesResult = layout.byteCount.multipliedReportingOverflow(by: bufferCount)
        guard !totalBytesResult.overflow, totalBytesResult.partialValue <= Int(Int32.max) else {
            throw RuntimeError.systemError(
                errno: EOVERFLOW, operation: .validateArgument("shared memory pool byte count"))
        }

        return totalBytesResult.partialValue
    }

    private static func createPool(
        sharedMemory: RawSharedMemory,
        fileDescriptor: Int32,
        totalBytes: Int
    ) throws(RuntimeError) -> OpaquePointer {
        guard
            let poolPointer = unsafe swl_shm_create_pool(
                sharedMemory.pointer,
                fileDescriptor,
                Int32(totalBytes)
            )
        else {
            throw RuntimeError.bindFailed("wl_shm_pool")
        }

        return poolPointer
    }

    private static func createBuffers(
        pool: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        mapping: SharedMemoryMapping,
        layout: BufferLayout,
        count: Int
    ) throws(RuntimeError) -> [RawBuffer] {
        var created: [RawBuffer] = []
        created.reserveCapacity(count)

        for index in 0..<count {
            let buffer = try createBuffer(
                pool: pool,
                proxyAdoption: adoptionContext,
                mapping: mapping,
                layout: layout,
                index: index
            )
            created.append(buffer)
        }

        return created
    }

    private static func createBuffer(
        pool: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        mapping: SharedMemoryMapping,
        layout: BufferLayout,
        index: Int
    ) throws(RuntimeError) -> RawBuffer {
        let offset = layout.byteCount * index
        guard
            let bufferPointer = unsafe swl_shm_pool_create_buffer(
                pool,
                Int32(offset),
                layout.width,
                layout.height,
                layout.stride,
                swl_shm_format_xrgb8888()
            )
        else {
            throw RuntimeError.bindFailed("wl_buffer")
        }

        return try RawBuffer(
            pointer: bufferPointer,
            proxyAdoption: adoptionContext,
            width: layout.width,
            height: layout.height,
            stride: layout.stride,
            bytes: .init(
                start: mapping.baseAddress.advanced(by: offset),
                count: layout.byteCount
            )
        )
    }
}
