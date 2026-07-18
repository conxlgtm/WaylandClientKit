import Synchronization

/// Stores the first completed value and shares it with every waiter.
///
/// Waiting intentionally ignores task cancellation. A cancelled task remains suspended until the
/// cell completes, then receives the same cached value as every other waiter.
@safe
package final class CompletionCell<Value: Sendable>: Sendable {
    private enum State {
        case pending([CheckedContinuation<Value, Never>])
        case completed(Value)
    }

    private enum WaitDisposition {
        case enqueued
        case completed(Value)
    }

    private enum CompletionDisposition {
        case won([CheckedContinuation<Value, Never>])
        case alreadyCompleted
    }

    private let state: Mutex<State>

    /// Creates a cell that waits for its first completed value.
    package init() {
        state = Mutex(.pending([]))
    }

    /// Creates a cell that already contains a completed value.
    package init(completed value: Value) {
        state = Mutex(.completed(value))
    }

    /// Returns the first completed value, suspending while the cell is pending.
    ///
    /// Cancelling the calling task does not cancel this wait.
    package func wait() async -> Value {
        await withCheckedContinuation { continuation in
            let disposition = state.withLock { state in
                switch state {
                case .pending(var waiters):
                    waiters.append(continuation)
                    state = .pending(waiters)
                    return WaitDisposition.enqueued
                case .completed(let value):
                    return WaitDisposition.completed(value)
                }
            }

            if case .completed(let value) = disposition {
                continuation.resume(returning: value)
            }
        }
    }

    /// Stores a value if the cell is pending and resumes its current waiters.
    ///
    /// - Returns: `true` if this call completed the cell, or `false` if another call completed it.
    @discardableResult
    package func complete(_ value: Value) -> Bool {
        let disposition = state.withLock { state in
            guard case .pending(let waiters) = state else {
                return CompletionDisposition.alreadyCompleted
            }

            state = .completed(value)
            return CompletionDisposition.won(waiters)
        }

        guard case .won(let waiters) = disposition else {
            return false
        }

        for waiter in waiters {
            waiter.resume(returning: value)
        }
        return true
    }

    #if ENABLE_TESTING
        package var pendingWaiterCountForTesting: Int {
            state.withLock { state in
                guard case .pending(let waiters) = state else {
                    return 0
                }
                return waiters.count
            }
        }
    #endif
}
