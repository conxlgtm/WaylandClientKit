@safe
final class CListenerStorage<Owner: AnyObject, Callbacks> {
    private let callbackStorage: CallbackBoxStorage<Owner>
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isInvalidated = false
    private var activeCallbackDepth = 0

    @safe let callbacks: UnsafeMutablePointer<Callbacks>

    @safe
    init(
        owner: Owner,
        initialValue: Callbacks,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        callbackStorage = CallbackBoxStorage(owner: owner)
        invariantFailureSink = failureSink
        callbacks = UnsafeMutablePointer<Callbacks>.allocate(capacity: 1)
        unsafe callbacks.initialize(to: initialValue)
    }

    @safe var opaqueOwnerPointer: UnsafeMutableRawPointer {
        unsafe UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    @safe var hasActiveCallbacksForTesting: Bool {
        activeCallbackDepth > 0
    }

    @safe var isValidForTesting: Bool {
        !isInvalidated && callbackStorage.isValid
    }

    @discardableResult
    @safe
    static func withOwner<Result>(
        from data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String =
            "Wayland listener fired after Swift owner was released",
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard let data = unsafe data else {
            RawInvariantFailureSink.trapForUnroutedFatalRawInvariantFailure(
                .callbackWithoutSwiftState(message())
            )
        }

        let storage = unsafe Unmanaged<CListenerStorage<Owner, Callbacks>>
            .fromOpaque(data)
            .takeUnretainedValue()
        return try storage.withOwner(message(), body)
    }

    @safe
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
        guard let invariantFailureSink else {
            RawInvariantFailureSink.trapForUnroutedFatalRawInvariantFailure(failure)
        }

        invariantFailureSink.reportFatalRawInvariantFailure(failure)
    }

    deinit {
        invalidate()
        unsafe callbacks.deinitialize(count: 1)
        unsafe callbacks.deallocate()
    }
}
