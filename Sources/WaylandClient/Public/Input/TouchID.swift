public struct TouchID: Equatable, Hashable, Sendable, CustomStringConvertible,
    ExpressibleByIntegerLiteral
{
    public typealias IntegerLiteralType = Int32

    public let rawValue: Int32

    public init(rawValue touchIDRawValue: Int32) {
        rawValue = touchIDRawValue
    }

    public init(integerLiteral value: Int32) {
        self.init(rawValue: value)
    }

    public var description: String {
        String(rawValue)
    }
}
