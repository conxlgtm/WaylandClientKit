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

    func requireOwner(
        _ message: @autoclosure () -> String =
            "Wayland listener fired after Swift owner was released"
    ) -> Owner {
        guard let owner = storedOwner else {
            preconditionFailure(message())
        }

        return owner
    }

    /// Returns an unretained opaque pointer to this callback box.
    ///
    /// The caller must ensure this `CallbackBox` remains alive for the
    /// entire duration the returned pointer is stored in C. Failure to
    /// do so is undefined behavior.
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
    /// Raw wrappers should strongly retain `CallbackBoxStorage` for exactly as long
    /// as the returned pointer is registered with C listener state.
    @safe var opaquePointer: UnsafeMutableRawPointer {
        box.toOpaque()
    }

    func invalidate() {
        box.invalidate()
    }
}
