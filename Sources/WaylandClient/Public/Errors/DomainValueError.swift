/// A validation failure for a reusable public domain value.
public enum DomainValueError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyString(type: String)
    case interiorNUL(type: String)
    case nonPositiveInt32(Int32)
    case nonPositiveInt(Int)
    case nonPositiveScaleNumerator(UInt32)
    case scaleNumeratorTooLarge(UInt32)
    case zeroScaleDenominator
    case negativeMilliseconds(Int32)

    public var description: String {
        switch self {
        case .emptyString(let type):
            "\(type) must not be empty"
        case .interiorNUL(let type):
            "\(type) must not contain embedded NUL bytes"
        case .nonPositiveInt32(let value):
            "expected a positive Int32, got \(value)"
        case .nonPositiveInt(let value):
            "expected a positive Int, got \(value)"
        case .nonPositiveScaleNumerator(let value):
            "scale numerator must be greater than zero, got \(value)"
        case .scaleNumeratorTooLarge(let value):
            "scale numerator must fit in Int32, got \(value)"
        case .zeroScaleDenominator:
            "scale denominator must be greater than zero"
        case .negativeMilliseconds(let value):
            "milliseconds must be greater than or equal to zero, got \(value)"
        }
    }
}
