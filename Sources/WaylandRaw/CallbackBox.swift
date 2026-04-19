public final class CallbackBox<Owner: AnyObject> {
    private weak var storedOwner: Owner?

    public init(_ owner: Owner) {
        self.storedOwner = owner
    }

    public var owner: Owner? {
        self.storedOwner
    }

    public var isValid: Bool {
        self.storedOwner != nil
    }

    public func invalidate() {
        self.storedOwner = nil
    }

    @discardableResult
    public func withOwner<Result>(
        _ body: (Owner) throws -> Result
    ) rethrows -> Result? {
        guard let owner = self.storedOwner else {
            return nil
        }

        return try body(owner)
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
        self.box = CallbackBox(owner)
    }

    public var owner: Owner? {
        self.box.owner
    }

    public var isValid: Bool {
        self.box.isValid
    }

    /// Returns an unretained opaque pointer while this storage keeps the box alive.
    ///
    /// Raw wrappers should strongly retain `CallbackBoxStorage` for exactly as long
    /// as the returned pointer is registered with C listener state.
    public var opaquePointer: UnsafeMutableRawPointer {
        self.box.toOpaque()
    }

    public func invalidate() {
        self.box.invalidate()
    }
}
