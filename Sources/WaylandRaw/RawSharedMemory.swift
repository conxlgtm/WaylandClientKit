import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public final class RawSharedMemory {
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(pointer sharedMemoryPointer: OpaquePointer, version sharedMemoryVersion: RawVersion) {
        pointer = sharedMemoryPointer
        version = sharedMemoryVersion
    }

    public func createPool(
        width: Int32,
        height: Int32,
        bufferCount: Int
    ) throws -> RawSharedMemoryPool {
        try .init(
            sharedMemory: self,
            width: width,
            height: height,
            bufferCount: bufferCount
        )
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        swl_shm_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

private final class SharedMemoryMapping {
    let fileDescriptor: Int32
    let byteCount: Int
    let baseAddress: UnsafeMutableRawPointer

    init(name: String, byteCount requestedByteCount: Int) throws {
        guard requestedByteCount > 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        let fd = try Self.createFileDescriptor(name: name)

        do {
            try Self.resizeFileDescriptor(fd, byteCount: requestedByteCount)
            baseAddress = try Self.mapFileDescriptor(fd, byteCount: requestedByteCount)
            fileDescriptor = fd
            byteCount = requestedByteCount
        } catch {
            close(fd)
            throw error
        }
    }

    private static func createFileDescriptor(name: String) throws -> Int32 {
        let fd = name.withCString { namePointer in
            swl_memfd_create(namePointer, swl_mfd_cloexec())
        }

        guard fd >= 0 else {
            throw RuntimeError.systemError(errno: errno)
        }

        return fd
    }

    private static func resizeFileDescriptor(_ fd: Int32, byteCount: Int) throws {
        guard ftruncate(fd, off_t(byteCount)) == 0 else {
            throw RuntimeError.systemError(errno: errno)
        }
    }

    private static func mapFileDescriptor(
        _ fd: Int32,
        byteCount: Int
    ) throws -> UnsafeMutableRawPointer {
        let mapped = mmap(
            nil,
            byteCount,
            PROT_READ | PROT_WRITE,
            MAP_SHARED,
            fd,
            0
        )

        guard let mapped, mapped != MAP_FAILED else {
            throw RuntimeError.systemError(errno: errno)
        }

        return mapped
    }

    deinit {
        munmap(baseAddress, byteCount)
        close(fileDescriptor)
    }
}

public struct BufferLayout: Equatable, Sendable {
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let byteCount: Int

    public init(width bufferWidth: Int32, height bufferHeight: Int32) throws {
        guard bufferWidth > 0, bufferHeight > 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        let strideResult = Int(bufferWidth).multipliedReportingOverflow(
            by: MemoryLayout<UInt32>.stride
        )
        guard !strideResult.overflow, strideResult.partialValue <= Int(Int32.max) else {
            throw RuntimeError.systemError(errno: EOVERFLOW)
        }

        let byteCountResult = strideResult.partialValue
            .multipliedReportingOverflow(by: Int(bufferHeight))
        guard !byteCountResult.overflow else {
            throw RuntimeError.systemError(errno: EOVERFLOW)
        }

        width = bufferWidth
        height = bufferHeight
        stride = Int32(strideResult.partialValue)
        byteCount = byteCountResult.partialValue
    }
}

public struct BufferBusyState: Equatable, Sendable {
    public private(set) var isBusy = false

    public init() {
        // Start reusable until the buffer is attached for presentation.
    }

    public mutating func markBusy() {
        isBusy = true
    }

    public mutating func markReleased() {
        isBusy = false
    }
}

private enum BufferReleaseInstallState {
    case idle
    case installed
}

private final class BufferReleaseOwner {
    private lazy var callbackStorage = CallbackBoxStorage(owner: self)
    private let callbacks: UnsafeMutablePointer<swl_buffer_listener_callbacks>
    private var onRelease: (() -> Void)?
    private var installState = BufferReleaseInstallState.idle

    init() {
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_buffer_listener_callbacks())

        callbacks.pointee.release = { data, _ in
            guard let data else {
                preconditionFailure("wl_buffer release fired without Swift state")
            }

            let owner = CallbackBox<BufferReleaseOwner>
                .fromOpaque(data)
                .requireOwner()
            owner.onRelease?()
        }
    }

    func install(
        on buffer: OpaquePointer,
        onRelease handler: @escaping () -> Void
    ) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        callbacks.pointee.data = callbackStorage.opaquePointer

        let result = swl_buffer_add_listener(buffer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        onRelease = handler
        installState = .installed
    }

    func cancel() {
        onRelease = nil
    }

    deinit {
        cancel()
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}

public final class RawBuffer {
    let pointer: OpaquePointer
    package let width: Int32
    package let height: Int32
    package let stride: Int32
    package let bytes: UnsafeMutableRawBufferPointer

    private let releaseOwner = BufferReleaseOwner()
    private var busyState = BufferBusyState()
    private var isDestroyed = false

    public var isBusy: Bool {
        busyState.isBusy
    }

    init(
        pointer bufferPointer: OpaquePointer,
        width bufferWidth: Int32,
        height bufferHeight: Int32,
        stride bufferStride: Int32,
        bytes bufferBytes: UnsafeMutableRawBufferPointer
    ) throws {
        pointer = bufferPointer
        width = bufferWidth
        height = bufferHeight
        stride = bufferStride
        bytes = bufferBytes

        try releaseOwner.install(on: bufferPointer) { [weak buffer = self] in
            guard let buffer else { return }

            buffer.markReleased()
        }
    }

    package func markBusy() {
        busyState.markBusy()
    }

    func markReleased() {
        busyState.markReleased()
    }

    public func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        releaseOwner.cancel()
        swl_buffer_destroy(pointer)
    }

    deinit {
        destroy()
    }
}

public final class RawSharedMemoryPool {
    public let size: TopLevelSize
    public let layout: BufferLayout

    private let mapping: SharedMemoryMapping
    private let pointer: OpaquePointer
    private let buffers: [RawBuffer]
    private var isDestroyed = false

    init(
        sharedMemory: RawSharedMemory,
        width: Int32,
        height: Int32,
        bufferCount: Int
    ) throws {
        guard bufferCount > 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }

        let bufferLayout = try BufferLayout(width: width, height: height)
        let totalBytes = try Self.totalByteCount(
            layout: bufferLayout,
            bufferCount: bufferCount
        )
        let memoryMapping = try SharedMemoryMapping(
            name: "swift-wayland-buffer-pool",
            byteCount: totalBytes
        )
        let poolPointer = try Self.createPool(
            sharedMemory: sharedMemory,
            mapping: memoryMapping,
            totalBytes: totalBytes
        )

        do {
            buffers = try Self.createBuffers(
                pool: poolPointer,
                mapping: memoryMapping,
                layout: bufferLayout,
                count: bufferCount
            )
            size = .init(width: width, height: height)
            layout = bufferLayout
            mapping = memoryMapping
            pointer = poolPointer
        } catch {
            swl_shm_pool_destroy(poolPointer)
            throw error
        }
    }

    package func nextFreeBuffer() -> RawBuffer? {
        buffers.first { !$0.isBusy }
    }

    public var hasBusyBuffers: Bool {
        buffers.contains(where: \.isBusy)
    }

    public func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        for buffer in buffers {
            buffer.destroy()
        }
        swl_shm_pool_destroy(pointer)
    }

    deinit {
        destroy()
    }

    private static func totalByteCount(
        layout: BufferLayout,
        bufferCount: Int
    ) throws -> Int {
        let totalBytesResult = layout.byteCount.multipliedReportingOverflow(by: bufferCount)
        guard !totalBytesResult.overflow, totalBytesResult.partialValue <= Int(Int32.max) else {
            throw RuntimeError.systemError(errno: EOVERFLOW)
        }

        return totalBytesResult.partialValue
    }

    private static func createPool(
        sharedMemory: RawSharedMemory,
        mapping: SharedMemoryMapping,
        totalBytes: Int
    ) throws -> OpaquePointer {
        guard
            let poolPointer = swl_shm_create_pool(
                sharedMemory.pointer,
                mapping.fileDescriptor,
                Int32(totalBytes)
            )
        else {
            throw RuntimeError.bindFailed("wl_shm_pool")
        }

        return poolPointer
    }

    private static func createBuffers(
        pool: OpaquePointer,
        mapping: SharedMemoryMapping,
        layout: BufferLayout,
        count: Int
    ) throws -> [RawBuffer] {
        var created: [RawBuffer] = []
        created.reserveCapacity(count)

        for index in 0..<count {
            let buffer = try createBuffer(
                pool: pool,
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
        mapping: SharedMemoryMapping,
        layout: BufferLayout,
        index: Int
    ) throws -> RawBuffer {
        let offset = layout.byteCount * index
        guard
            let bufferPointer = swl_shm_pool_create_buffer(
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

        do {
            return try RawBuffer(
                pointer: bufferPointer,
                width: layout.width,
                height: layout.height,
                stride: layout.stride,
                bytes: .init(
                    start: mapping.baseAddress.advanced(by: offset),
                    count: layout.byteCount
                )
            )
        } catch {
            swl_buffer_destroy(bufferPointer)
            throw error
        }
    }
}
