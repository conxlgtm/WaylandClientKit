import Foundation

// SAFETY: `value` is private and every access is protected by an `NSLock`
// acquired before Swift begins the sanitizer-visible inout access.
@safe
final class EventBrokerLockedState<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: State

    init(_ initialValue: consuming State) {
        value = initialValue
    }

    func withLock<Result>(
        _ body: (inout State) throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
