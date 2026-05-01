import CWaylandClientSystem
import CWaylandProtocols
import Glibc

struct WaylandCallbackOperations {
    let addListener: (OpaquePointer?, UnsafePointer<swl_callback_listener_callbacks>?) -> Int32
    let destroy: (OpaquePointer?) -> Void

    static var live: WaylandCallbackOperations {
        .init(
            addListener: swl_callback_add_listener,
            destroy: swl_callback_destroy
        )
    }
}

enum WaylandCallbackLifecycle: Equatable {
    case pending
    case firing
    case fired
    case cancelled
}

final class WaylandCallbackRegistrationState {
    private var pointer: OpaquePointer?
    private let operations: WaylandCallbackOperations
    private let invariantFailureSink: RawInvariantFailureSink?
    private var onDone: (() -> Void)?
    private(set) var lifecycle: WaylandCallbackLifecycle = .pending
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_callback_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        pointer callbackPointer: OpaquePointer,
        onDone handler: @escaping () -> Void,
        operations callbackOperations: WaylandCallbackOperations,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        pointer = callbackPointer
        onDone = handler
        invariantFailureSink = failureSink
        operations = callbackOperations

        callbacks.pointee.done = { data, _, _ in
            CListenerStorage<
                WaylandCallbackRegistrationState,
                swl_callback_listener_callbacks
            >.withOwner(
                from: data,
                message: "Wayland callback fired without Swift state"
            ) { state in
                state.handleDone()
            }
        }
    }

    func install() throws {
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        guard let pointer else {
            preconditionFailure("Wayland callback listener installed after ownership ended")
        }

        let result = operations.addListener(pointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(errno: EINVAL)
        }
    }

    func handleDone() {
        guard lifecycle == .pending, let callback = unsafe pointer else {
            preconditionFailure("Wayland callback fired after completion")
        }

        let handler = onDone
        let retainedListenerStorage = unsafe listenerStorage
        onDone = nil
        unsafe pointer = nil
        lifecycle = .fired
        retainedListenerStorage.invalidate()

        unsafe operations.destroy(callback)

        unsafe withExtendedLifetime(retainedListenerStorage) {
            handler?()
        }
    }

    func cancel() {
        guard lifecycle == .pending else {
            onDone = nil
            return
        }

        lifecycle = .cancelled
        let callback = pointer
        pointer = nil
        onDone = nil
        listenerStorage.invalidate()
        if let callback {
            operations.destroy(callback)
        }
    }

    deinit {
        cancel()
    }
}

public struct FrameCallbackRegistration: ~Copyable {
    private let state: WaylandCallbackRegistrationState

    init(
        pointer callbackPointer: OpaquePointer,
        onDone handler: @escaping () -> Void,
        operations callbackOperations: WaylandCallbackOperations = .live,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) throws {
        let newState = WaylandCallbackRegistrationState(
            pointer: callbackPointer,
            onDone: handler,
            operations: callbackOperations,
            invariantFailureSink: failureSink
        )

        do {
            try newState.install()
        } catch {
            newState.cancel()
            throw error
        }

        state = newState
    }

    public consuming func cancel() {
        state.cancel()
    }

    deinit {
        state.cancel()
    }
}
