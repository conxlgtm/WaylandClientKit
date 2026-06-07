import CWaylandProtocols
import Glibc

package struct RawLinuxDmabufBufferParamsFlags: OptionSet, Sendable, KnownUInt32OptionSet {
    package let rawValue: UInt32

    package init(rawValue flags: UInt32) {
        rawValue = flags
    }

    package static let yInvert = RawLinuxDmabufBufferParamsFlags(rawValue: 1)
    package static let interlaced = RawLinuxDmabufBufferParamsFlags(rawValue: 2)
    package static let bottomFirst = RawLinuxDmabufBufferParamsFlags(rawValue: 4)
    package static let known: RawLinuxDmabufBufferParamsFlags = [
        .yInvert,
        .interlaced,
        .bottomFirst,
    ]
}

package enum RawLinuxDmabufBufferParamsLifecycle: Equatable, Sendable {
    case collecting
    case createRequested
    case created
    case failed
    case destroyed
}

package enum RawLinuxDmabufBufferParamsStateError: Error, Equatable, CustomStringConvertible {
    case addAfterCreateRequest
    case createAfterCreateRequest
    case createWithoutPlanes
    case duplicatePlaneIndex(UInt32)
    case nonConsecutivePlaneIndices(Set<UInt32>)
    case createdBeforeCreateRequest
    case failedBeforeCreateRequest
    case useAfterTerminalState(RawLinuxDmabufBufferParamsLifecycle)

    package var description: String {
        switch self {
        case .addAfterCreateRequest:
            "add plane after linux-dmabuf buffer create request"
        case .createAfterCreateRequest:
            "repeat linux-dmabuf buffer create request"
        case .createWithoutPlanes:
            "linux-dmabuf buffer create request without planes"
        case .duplicatePlaneIndex(let planeIndex):
            "duplicate linux-dmabuf plane index \(planeIndex)"
        case .nonConsecutivePlaneIndices(let planeIndices):
            "non-consecutive linux-dmabuf plane indices \(planeIndices.sorted())"
        case .createdBeforeCreateRequest:
            "linux-dmabuf buffer params created before create request"
        case .failedBeforeCreateRequest:
            "linux-dmabuf buffer params failed before create request"
        case .useAfterTerminalState(let lifecycle):
            "use linux-dmabuf buffer params after \(lifecycle)"
        }
    }
}

package struct RawLinuxDmabufBufferParamsState: Equatable, Sendable {
    package private(set) var lifecycle = RawLinuxDmabufBufferParamsLifecycle.collecting
    package private(set) var planeIndices: Set<UInt32> = []

    package init() {
        // Stored property defaults model a fresh params object.
    }

    package mutating func prepareAddPlane(
        fileDescriptor: inout RawLinuxDmabufPlaneFileDescriptor,
        planeIndex: UInt32
    ) throws(RawLinuxDmabufBufferParamsStateError) -> Int32 {
        switch lifecycle {
        case .collecting:
            guard !planeIndices.contains(planeIndex) else {
                fileDescriptor.close()
                throw RawLinuxDmabufBufferParamsStateError.duplicatePlaneIndex(planeIndex)
            }
            planeIndices.insert(planeIndex)
            return fileDescriptor.releaseForWaylandRequest()
        case .createRequested:
            fileDescriptor.close()
            throw RawLinuxDmabufBufferParamsStateError.addAfterCreateRequest
        case .created, .failed, .destroyed:
            fileDescriptor.close()
            throw RawLinuxDmabufBufferParamsStateError.useAfterTerminalState(lifecycle)
        }
    }

    package mutating func prepareCreate()
        throws(RawLinuxDmabufBufferParamsStateError)
    {
        switch lifecycle {
        case .collecting:
            guard !planeIndices.isEmpty else {
                throw RawLinuxDmabufBufferParamsStateError.createWithoutPlanes
            }
            let expectedPlaneIndices = Set(UInt32(0)..<UInt32(planeIndices.count))
            guard planeIndices == expectedPlaneIndices else {
                throw
                    RawLinuxDmabufBufferParamsStateError
                    .nonConsecutivePlaneIndices(planeIndices)
            }
            lifecycle = .createRequested
        case .createRequested:
            throw RawLinuxDmabufBufferParamsStateError.createAfterCreateRequest
        case .created, .failed, .destroyed:
            throw RawLinuxDmabufBufferParamsStateError.useAfterTerminalState(lifecycle)
        }
    }

    package mutating func markCreated()
        throws(RawLinuxDmabufBufferParamsStateError)
    {
        switch lifecycle {
        case .collecting:
            throw RawLinuxDmabufBufferParamsStateError.createdBeforeCreateRequest
        case .createRequested:
            lifecycle = .created
        case .created, .failed, .destroyed:
            throw RawLinuxDmabufBufferParamsStateError.useAfterTerminalState(lifecycle)
        }
    }

    package mutating func markFailed()
        throws(RawLinuxDmabufBufferParamsStateError)
    {
        switch lifecycle {
        case .collecting:
            throw RawLinuxDmabufBufferParamsStateError.failedBeforeCreateRequest
        case .createRequested:
            lifecycle = .failed
        case .created, .failed, .destroyed:
            throw RawLinuxDmabufBufferParamsStateError.useAfterTerminalState(lifecycle)
        }
    }

    package mutating func markDestroyed() {
        lifecycle = .destroyed
    }
}

package enum RawLinuxDmabufBufferParamsEvent {
    case created(RawLinuxDmabufBuffer)
    case failed
}

@safe
// SAFETY: RawLinuxDmabufBuffer owns its wl_buffer proxy and release listener;
// managed GPU presentation moves it into a presenter buffer that serializes
// destroy/release handling before exposing only typed frame results.
// swiftlint:disable:next attributes
package final class RawLinuxDmabufBuffer: @unchecked Sendable {
    private let releaseOwner: BufferReleaseOwner
    private var releaseObserver: (() -> Void)?
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer bufferPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        releaseOwner = BufferReleaseOwner(
            invariantFailureSink: adoptionContext.invariantFailureSink
        )
        proxy = try RawOwnedProxy(
            adopting: bufferPointer,
            interface: "wl_buffer",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_buffer_destroy
        )

        try unsafe releaseOwner.install(on: pointer) { [weak buffer = self] in
            buffer?.handleRelease()
        }
    }

    package func setReleaseObserver(_ observer: @escaping () -> Void) {
        releaseObserver = observer
    }

    private func handleRelease() {
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

@safe
package final class RawLinuxDmabufBufferParams {
    private let listenerOwner: RawLinuxDmabufBufferParamsOwner
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    package var lifecycle: RawLinuxDmabufBufferParamsLifecycle {
        listenerOwner.lifecycle
    }

    @safe
    init(
        pointer paramsPointer: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onEvent handleEvent: @escaping (RawLinuxDmabufBufferParamsEvent) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws(RuntimeError) {
        listenerOwner = RawLinuxDmabufBufferParamsOwner(
            proxyAdoption: adoptionContext,
            onEvent: handleEvent,
            onFailure: handleFailure
        )
        proxy = try RawOwnedProxy(
            adopting: paramsPointer,
            interface: "zwp_linux_buffer_params_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_linux_buffer_params_v1_destroy
        )
        try unsafe listenerOwner.install(on: pointer)
    }

    package func addPlane(
        fileDescriptor planeDescriptor: inout RawLinuxDmabufPlaneFileDescriptor,
        planeIndex: UInt32,
        offset: UInt32,
        stride: UInt32,
        modifier: UInt64
    ) throws(RuntimeError) {
        do {
            let fd = try listenerOwner.prepareAddPlane(
                fileDescriptor: &planeDescriptor,
                planeIndex: planeIndex
            )
            defer {
                Glibc.close(fd)
            }
            unsafe swl_zwp_linux_buffer_params_v1_add(
                pointer,
                fd,
                planeIndex,
                offset,
                stride,
                UInt32(modifier >> 32),
                UInt32(modifier & 0xffff_ffff)
            )
        } catch {
            throw RuntimeError.invalidArgument(error.description)
        }
    }

    package func create(
        width: Int32,
        height: Int32,
        format: UInt32,
        flags: RawLinuxDmabufBufferParamsFlags = []
    ) throws(RuntimeError) {
        guard width > 0, height > 0 else {
            throw RuntimeError.invalidArgument("dmabuf buffer dimensions")
        }

        do {
            try listenerOwner.prepareCreate()
            unsafe swl_zwp_linux_buffer_params_v1_create(
                pointer,
                width,
                height,
                format,
                flags.rawValue
            )
        } catch {
            throw RuntimeError.invalidArgument(error.description)
        }
    }

    package func destroy() {
        listenerOwner.markDestroyed()
        listenerOwner.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
private final class RawLinuxDmabufBufferParamsOwner {
    private let proxyAdoption: RawProxyAdoptionContext
    private let onEvent: (RawLinuxDmabufBufferParamsEvent) -> Void
    private let onFailure: (RuntimeError) -> Void
    private var state = RawLinuxDmabufBufferParamsState()
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_linux_buffer_params_listener_callbacks(),
        invariantFailureSink: proxyAdoption.invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_linux_buffer_params_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    var lifecycle: RawLinuxDmabufBufferParamsLifecycle {
        state.lifecycle
    }

    init(
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        onEvent handleEvent: @escaping (RawLinuxDmabufBufferParamsEvent) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) {
        proxyAdoption = adoptionContext
        onEvent = handleEvent
        onFailure = handleFailure

        unsafe callbacks.pointee.created = { data, _, buffer in
            guard let buffer = unsafe buffer else { return }
            RawLinuxDmabufBufferParamsOwner.withOwner(
                data,
                message: "zwp_linux_buffer_params_v1 created fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else {
                    unsafe swl_buffer_destroy(buffer)
                    return
                }
                unsafe owner.handleCreated(buffer: buffer)
            }
        }
        unsafe callbacks.pointee.failed = { data, _ in
            RawLinuxDmabufBufferParamsOwner.withOwner(
                data,
                message: "zwp_linux_buffer_params_v1 failed fired without Swift state"
            ) { owner in
                guard !owner.isCanceled else { return }
                owner.handleFailed()
            }
        }
    }

    func install(on params: OpaquePointer) throws(RuntimeError) {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_zwp_linux_buffer_params_v1_add_listener(
            params,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_linux_buffer_params_v1")
            )
        }
    }

    func prepareAddPlane(
        fileDescriptor: inout RawLinuxDmabufPlaneFileDescriptor,
        planeIndex: UInt32
    ) throws(RawLinuxDmabufBufferParamsStateError) -> Int32 {
        try state.prepareAddPlane(fileDescriptor: &fileDescriptor, planeIndex: planeIndex)
    }

    func prepareCreate() throws(RawLinuxDmabufBufferParamsStateError) {
        try state.prepareCreate()
    }

    func markDestroyed() {
        state.markDestroyed()
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func handleCreated(buffer: OpaquePointer) {
        do {
            try state.markCreated()
            let wrappedBuffer = try RawLinuxDmabufBuffer(
                pointer: buffer,
                proxyAdoption: proxyAdoption
            )
            onEvent(.created(wrappedBuffer))
        } catch let error as RawLinuxDmabufBufferParamsStateError {
            unsafe swl_buffer_destroy(buffer)
            onFailure(runtimeError(for: error))
        } catch {
            onFailure(runtimeError(from: error))
        }
    }

    private func handleFailed() {
        do {
            try state.markFailed()
            onEvent(.failed)
        } catch {
            onFailure(runtimeError(for: error))
        }
    }

    private func runtimeError(
        for error: RawLinuxDmabufBufferParamsStateError
    ) -> RuntimeError {
        RuntimeError.invalidArgument(error.description)
    }

    private func runtimeError(from error: any Error) -> RuntimeError {
        RuntimeError.fromRuntimeOrInvalidArgument(error)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawLinuxDmabufBufferParamsOwner) -> Void
    ) {
        CListenerStorage<
            RawLinuxDmabufBufferParamsOwner,
            swl_zwp_linux_buffer_params_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
