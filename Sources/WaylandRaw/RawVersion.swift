public struct RawVersion: Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral,
    CustomStringConvertible
{
    public let value: UInt32

    public init(_ rawValue: UInt32) {
        value = rawValue
    }

    public init(integerLiteral rawValue: UInt32) {
        value = rawValue
    }

    public static func < (lhs: RawVersion, rhs: RawVersion) -> Bool {
        lhs.value < rhs.value
    }

    public var description: String {
        "v\(value)"
    }
}
