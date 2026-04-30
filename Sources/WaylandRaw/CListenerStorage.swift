final class CListenerStorage<Owner: AnyObject, Callbacks> {
    private let callbackStorage: CallbackBoxStorage<Owner>
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isInvalidated = false
    private var activeCallbackDepth = 0

    let callbacks: UnsafeMutablePointer<Callbacks>

    init(
        owner: Owner,
        initialValue: Callbacks,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        callbackStorage = CallbackBoxStorage(owner: owner)
        invariantFailureSink = failureSink
        callbacks = .allocate(capacity: 1)
        callbacks.initialize(to: initialValue)
    }

    var opaqueOwnerPointer: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    var hasActiveCallbacksForTesting: Bool {
        activeCallbackDepth > 0
    }

    var isValidForTesting: Bool {
        !isInvalidated && callbackStorage.isValid
    }

    @discardableResult
    static func withOwner<Result>(
        from data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String =
            "Wayland listener fired after Swift owner was released",
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard let data else {
            #if DEBUG
                preconditionFailure(message())
            #else
                return nil
            #endif
        }

        let storage = Unmanaged<CListenerStorage<Owner, Callbacks>>
            .fromOpaque(data)
            .takeUnretainedValue()
        return try storage.withOwner(message(), body)
    }

    func invalidate() {
        guard !isInvalidated else { return }

        isInvalidated = true
        callbackStorage.invalidate()
    }

    #if DEBUG
        func reportFatalInvariantFailureForTesting(_ failure: RawInvariantFailure) {
            invariantFailureSink?.reportFatalRawInvariantFailure(failure)
        }
    #endif

    private func withOwner<Result>(
        _ message: @autoclosure () -> String,
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard !isInvalidated, let owner = callbackStorage.owner else {
            reportFatalInvariantFailure(.callbackWithoutSwiftState(message()))
            #if DEBUG
                preconditionFailure(message())
            #else
                return nil
            #endif
        }

        activeCallbackDepth += 1
        defer {
            activeCallbackDepth -= 1
        }

        return try body(owner)
    }

    private func reportFatalInvariantFailure(_ failure: RawInvariantFailure) {
        invariantFailureSink?.reportFatalRawInvariantFailure(failure)
    }

    deinit {
        invalidate()
        callbacks.deinitialize(count: 1)
        callbacks.deallocate()
    }
}
