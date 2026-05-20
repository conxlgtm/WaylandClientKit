import Foundation

// SAFETY: State is private to its owner and every access is serialized by NSLock.
@safe
final class EventBrokerLockedState<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    init(_ initialState: State) {
        state = initialState
    }

    func withLock<Result>(
        _ body: (inout State) throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}
