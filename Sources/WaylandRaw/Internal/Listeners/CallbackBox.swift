@safe
final class CallbackBox<Owner: AnyObject> {
    private weak var storedOwner: Owner?

    init(_ owner: Owner) {
        storedOwner = owner
    }

    var owner: Owner? {
        storedOwner
    }

    var isValid: Bool {
        storedOwner != nil
    }

    func invalidate() {
        storedOwner = nil
    }

    @discardableResult
    func withOwner<Result>(
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard let owner = storedOwner else {
            return nil
        }

        return try body(owner)
    }

    /// Returns an unretained opaque pointer to this callback box.
    ///
    /// The pointer is valid while C stores it only if this `CallbackBox` remains
    /// alive for the same period.
    @safe
    func toOpaque() -> UnsafeMutableRawPointer {
        unsafe UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    @safe
    static func fromOpaque(
        _ pointer: UnsafeMutableRawPointer
    ) -> CallbackBox<Owner> {
        unsafe Unmanaged<CallbackBox<Owner>>
            .fromOpaque(pointer)
            .takeUnretainedValue()
    }
}

@safe
final class CallbackBoxStorage<Owner: AnyObject> {
    let box: CallbackBox<Owner>

    init(owner: Owner) {
        box = CallbackBox(owner)
    }

    var owner: Owner? {
        box.owner
    }

    var isValid: Bool {
        box.isValid
    }

    /// Returns an unretained opaque pointer while this storage keeps the box alive.
    ///
    /// The pointer remains valid while this storage is retained by the raw wrapper.
    @safe var opaquePointer: UnsafeMutableRawPointer {
        box.toOpaque()
    }

    func invalidate() {
        box.invalidate()
    }
}
