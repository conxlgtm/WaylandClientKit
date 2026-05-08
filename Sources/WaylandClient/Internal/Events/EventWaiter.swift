import Synchronization

typealias EventWaiter<Element: Sendable> =
    CheckedContinuation<Result<Element?, WaylandDisplayError>, Never>

struct EventWaiterID: Hashable, Sendable {
    let rawValue: UInt64
}

enum EventWaiterState<Element: Sendable> {
    case pending
    case waiting(EventWaiter<Element>)
    case cancelled
    case completed
}

@safe
final class EventWaiterBox<Element: Sendable>: Sendable {
    let id: EventWaiterID

    private let state = Mutex<EventWaiterState<Element>>(.pending)

    init(id waiterID: EventWaiterID) {
        id = waiterID
    }

    func install(
        _ continuation: EventWaiter<Element>
    ) -> Result<Element?, WaylandDisplayError>? {
        state.withLock { waiterState in
            switch waiterState {
            case .pending:
                waiterState = .waiting(continuation)
                return nil
            case .cancelled:
                waiterState = .waiting(continuation)
                return .success(nil)
            case .waiting, .completed:
                preconditionFailure("event waiter installed more than once")
            }
        }
    }

    func cancel() -> EventWaiter<Element>? {
        state.withLock { waiterState in
            switch waiterState {
            case .pending:
                waiterState = .cancelled
                return nil
            case .waiting(let continuation):
                waiterState = .completed
                return continuation
            case .cancelled, .completed:
                return nil
            }
        }
    }

    func cancelIfPending() {
        state.withLock { waiterState in
            guard case .pending = waiterState else {
                return
            }

            waiterState = .cancelled
        }
    }

    func resume() -> EventWaiter<Element>? {
        state.withLock { waiterState in
            switch waiterState {
            case .pending:
                preconditionFailure("event waiter resumed before continuation installation")
            case .waiting(let continuation):
                waiterState = .completed
                return continuation
            case .cancelled, .completed:
                return nil
            }
        }
    }
}
