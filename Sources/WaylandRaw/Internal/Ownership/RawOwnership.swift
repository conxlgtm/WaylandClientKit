package enum RawOwnership: String, Sendable, CustomStringConvertible {
    case borrowed
    case destroyRequest
    case releaseRequest
    case connectionLifetime

    package var description: String {
        rawValue
    }
}
