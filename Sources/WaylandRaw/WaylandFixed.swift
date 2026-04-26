public struct WaylandFixed: Equatable, Sendable, ExpressibleByIntegerLiteral,
    CustomStringConvertible
{
    public let rawValue: Int32

    public init(rawValue fixedRawValue: Int32) {
        rawValue = fixedRawValue
    }

    public init(integerLiteral fixedRawValue: Int32) {
        rawValue = fixedRawValue
    }

    public var doubleValue: Double {
        Double(rawValue) / 256.0
    }

    public var description: String {
        "\(doubleValue)"
    }
}
