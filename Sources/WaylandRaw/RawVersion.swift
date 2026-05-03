package struct RawVersion: Hashable, Sendable, Comparable, ExpressibleByIntegerLiteral,
    CustomStringConvertible
{
    package let value: UInt32

    package init(_ rawValue: UInt32) {
        value = rawValue
    }

    package init(integerLiteral rawValue: UInt32) {
        value = rawValue
    }

    package static func < (lhs: RawVersion, rhs: RawVersion) -> Bool {
        lhs.value < rhs.value
    }

    package var description: String {
        "v\(value)"
    }
}
