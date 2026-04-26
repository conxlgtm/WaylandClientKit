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
    private var onDone: (() -> Void)?
    private(set) var lifecycle: WaylandCallbackLifecycle = .pending
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_callback_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(
        pointer callbackPointer: OpaquePointer,
        onDone handler: @escaping () -> Void,
        operations callbackOperations: WaylandCallbackOperations
    ) {
        pointer = callbackPointer
        onDone = handler
        operations = callbackOperations

        callbacks.pointee.done = { data, _, _ in
            guard let data else {
                preconditionFailure("Wayland callback fired without Swift state")
            }

            let state = CallbackBox<WaylandCallbackRegistrationState>
                .fromOpaque(data)
                .requireOwner("Wayland callback fired without Swift state")
            state.handleDone()
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
        guard lifecycle == .pending else {
            preconditionFailure("Wayland callback fired after completion")
        }

        lifecycle = .firing
        let handler = onDone
        onDone = nil
        pointer = nil
        lifecycle = .fired
        handler?()
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
        operations callbackOperations: WaylandCallbackOperations = .live
    ) throws {
        let newState = WaylandCallbackRegistrationState(
            pointer: callbackPointer,
            onDone: handler,
            operations: callbackOperations
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
