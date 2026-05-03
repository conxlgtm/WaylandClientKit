import CWaylandProtocols
import Glibc

private enum BufferReleaseInstallState {
    case idle
    case installed
}

final class BufferReleaseOwner {
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
