public enum RawOwnership: String, Sendable, CustomStringConvertible {
    case borrowed
    case destroyRequest
    case releaseRequest
    case connectionLifetime

    public var description: String {
        rawValue
    }
}
