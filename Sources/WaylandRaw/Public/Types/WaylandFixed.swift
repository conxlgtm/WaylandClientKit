package struct WaylandFixed: Equatable, Sendable, ExpressibleByIntegerLiteral,
    CustomStringConvertible
{
    package let rawValue: Int32

    package init(rawValue fixedRawValue: Int32) {
        rawValue = fixedRawValue
    }

    package init(integerLiteral fixedRawValue: Int32) {
        rawValue = fixedRawValue
    }

    package var doubleValue: Double {
        Double(rawValue) / 256.0
    }

    package var description: String {
        "\(doubleValue)"
    }
}
