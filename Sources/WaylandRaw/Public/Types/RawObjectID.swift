package struct RawObjectID: Hashable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible
{
    package let value: UInt32

    package init(_ rawValue: UInt32) {
        value = rawValue
    }

    package init(integerLiteral rawValue: UInt32) {
        value = rawValue
    }

    package var description: String {
        "id=\(value)"
    }
}
