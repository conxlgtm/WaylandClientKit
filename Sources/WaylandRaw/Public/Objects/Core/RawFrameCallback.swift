import CWaylandClientSystem
import CWaylandProtocols
import Glibc

@safe
struct WaylandCallbackOperations {
    @safe let addListener:
        (OpaquePointer?, UnsafePointer<swl_callback_listener_callbacks>?) -> Int32
    @safe let destroy: (OpaquePointer?) -> Void

    static var live: WaylandCallbackOperations {
        unsafe .init(
            addListener: { unsafe swl_callback_add_listener($0, $1) },
            destroy: { unsafe swl_callback_destroy($0) }
        )
    }
}

enum WaylandCallbackLifecycle: Equatable {
    case pending
    case completed(WaylandCallbackCompletionReason)
}

enum WaylandCallbackCompletionReason: Equatable {
    case fired
    case cancelled
}

@safe
private enum WaylandCallbackState {
    case pending(pointer: OpaquePointer, onDone: () -> Void)
    case completed(WaylandCallbackCompletionReason)

    var lifecycle: WaylandCallbackLifecycle {
        switch self {
        case .pending:
            .pending
        case .completed(let reason):
            .completed(reason)
        }
    }
}

@safe
final class WaylandCallbackRegistrationState {
    private var state: WaylandCallbackState
    private let operations: WaylandCallbackOperations
    private let invariantFailureSink: RawInvariantFailureSink?
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_callback_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_callback_listener_callbacks> {
        listenerStorage.callbacks
    }

    @safe
    init(
        pointer callbackPointer: OpaquePointer,
        onDone handler: @escaping () -> Void,
        operations callbackOperations: WaylandCallbackOperations,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        unsafe state = .pending(pointer: callbackPointer, onDone: handler)
        invariantFailureSink = failureSink
        operations = callbackOperations

        unsafe callbacks.pointee.done = { data, _, _ in
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

    var lifecycle: WaylandCallbackLifecycle {
        state.lifecycle
    }

    var listenerStorageIsValidForTesting: Bool {
        listenerStorage.isValidForTesting
    }

    var listenerStorageCallbackActive: Bool {
        listenerStorage.hasActiveCallbacksForTesting
    }

    func install() throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        guard case .pending(let pointer, _) = state else {
            preconditionFailure("Wayland callback listener installed after ownership ended")
        }

        let result = unsafe operations.addListener(pointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wl_callback")
            )
        }
    }

    func handleDone() {
        guard case .pending(let callback, let handler) = state else {
            preconditionFailure("Wayland callback fired after completion")
        }

        let retainedListenerStorage = listenerStorage
        state = .completed(.fired)
        retainedListenerStorage.invalidate()

        unsafe operations.destroy(callback)

        unsafe withExtendedLifetime(retainedListenerStorage) {
            handler()
        }
    }

    func cancel() {
        guard case .pending(let callback, _) = state else {
            return
        }

        state = .completed(.cancelled)
        listenerStorage.invalidate()
        unsafe operations.destroy(callback)
    }

    deinit {
        cancel()
    }
}

@safe
package struct FrameCallbackRegistration: ~Copyable {
    private let state: WaylandCallbackRegistrationState

    @safe
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

    package consuming func cancel() {
        state.cancel()
    }

    deinit {
        state.cancel()
    }
}
