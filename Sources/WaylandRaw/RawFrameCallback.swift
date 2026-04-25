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
    private let callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks>
    private var onDone: (() -> Void)?
    private(set) var lifecycle: WaylandCallbackLifecycle = .pending

    init(
        pointer callbackPointer: OpaquePointer,
        onDone handler: @escaping () -> Void,
        operations callbackOperations: WaylandCallbackOperations
    ) {
        pointer = callbackPointer
        onDone = handler
        operations = callbackOperations
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: swl_callback_listener_callbacks())

        callbacks.pointee.done = { data, _, _ in
            guard let data else {
                preconditionFailure("Wayland frame callback fired without Swift state")
            }

            let state = Unmanaged<WaylandCallbackRegistrationState>
                .fromOpaque(data)
                .retain()
                .takeRetainedValue()
            state.handleDone()
        }
    }

    func install() throws {
        callbacks.pointee.data = Unmanaged.passUnretained(self).toOpaque()
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
            preconditionFailure("Wayland frame callback fired after completion")
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
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
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

    func keepAliveForCallbackLifetime() {
        // A deliberate no-op used when the callback may fire before scope exit.
    }

    deinit {
        state.cancel()
    }
}
