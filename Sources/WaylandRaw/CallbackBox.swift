public final class CallbackBox<Owner: AnyObject> {
    private weak var storedOwner: Owner?

    public init(_ owner: Owner) {
        storedOwner = owner
    }

    public var owner: Owner? {
        storedOwner
    }

    public var isValid: Bool {
        storedOwner != nil
    }

    public func invalidate() {
        storedOwner = nil
    }

    @discardableResult
    public func withOwner<Result>(
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard let owner = storedOwner else {
            return nil
        }

        return try body(owner)
    }

    public func requireOwner(
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
    public func toOpaque() -> UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    public static func fromOpaque(
        _ pointer: UnsafeMutableRawPointer
    ) -> CallbackBox<Owner> {
        Unmanaged<CallbackBox<Owner>>
            .fromOpaque(pointer)
            .takeUnretainedValue()
    }
}

public final class CallbackBoxStorage<Owner: AnyObject> {
    public let box: CallbackBox<Owner>

    public init(owner: Owner) {
        box = CallbackBox(owner)
    }

    public var owner: Owner? {
        box.owner
    }

    public var isValid: Bool {
        box.isValid
    }

    /// Returns an unretained opaque pointer while this storage keeps the box alive.
    ///
    /// Raw wrappers should strongly retain `CallbackBoxStorage` for exactly as long
    /// as the returned pointer is registered with C listener state.
    public var opaquePointer: UnsafeMutableRawPointer {
        box.toOpaque()
    }

    public func invalidate() {
        box.invalidate()
    }
}
