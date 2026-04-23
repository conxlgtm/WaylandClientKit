public struct RawObjectID: Hashable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible
{
    public let value: UInt32

    public init(_ rawValue: UInt32) {
        value = rawValue
    }

    public init(integerLiteral rawValue: UInt32) {
        value = rawValue
    }

    public var description: String {
        "id=\(value)"
    }
}
