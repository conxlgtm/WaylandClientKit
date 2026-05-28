public struct SeatName: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    public let rawValue: String

    public init?(rawValue seatNameRawValue: String) {
        guard !seatNameRawValue.isEmpty else {
            return nil
        }

        rawValue = seatNameRawValue
    }

    public var description: String {
        rawValue
    }
}

public struct WaylandTimestampMilliseconds: RawRepresentable, Equatable, Hashable,
    Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: UInt32

    public init(rawValue timestampRawValue: UInt32) {
        rawValue = timestampRawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct WaylandTimestampMicroseconds: RawRepresentable, Equatable, Hashable,
    Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: UInt64

    public init(rawValue timestampRawValue: UInt64) {
        rawValue = timestampRawValue
    }

    public init(integerLiteral value: UInt64) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct PointerButtonCode: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: UInt32

    public init(rawValue buttonRawValue: UInt32) {
        rawValue = buttonRawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct EvdevKeycode: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: UInt32

    public init(rawValue keycodeRawValue: UInt32) {
        rawValue = keycodeRawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct XKBKeycode: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: UInt32

    public init(rawValue keycodeRawValue: UInt32) {
        rawValue = keycodeRawValue
    }

    public init(integerLiteral value: UInt32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct PointerAxisDiscreteStep: RawRepresentable, Equatable, Hashable,
    Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: Int32

    public init(rawValue stepRawValue: Int32) {
        rawValue = stepRawValue
    }

    public init(integerLiteral value: Int32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public struct PointerAxisValue120: RawRepresentable, Equatable, Hashable,
    Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral
{
    public let rawValue: Int32

    public init(rawValue valueRawValue: Int32) {
        rawValue = valueRawValue
    }

    public init(integerLiteral value: Int32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }
}

public enum PointerAxis: Equatable, Sendable {
    case verticalScroll
    case horizontalScroll
    case unknown(UInt32)

    public init(rawValue axisRawValue: UInt32) {
        switch axisRawValue {
        case 0:
            self = .verticalScroll
        case 1:
            self = .horizontalScroll
        default:
            self = .unknown(axisRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .verticalScroll:
            0
        case .horizontalScroll:
            1
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum PointerAxisSource: Equatable, Sendable {
    case wheel
    case finger
    case continuous
    case wheelTilt
    case unknown(UInt32)

    public init(rawValue sourceRawValue: UInt32) {
        switch sourceRawValue {
        case 0:
            self = .wheel
        case 1:
            self = .finger
        case 2:
            self = .continuous
        case 3:
            self = .wheelTilt
        default:
            self = .unknown(sourceRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .wheel:
            0
        case .finger:
            1
        case .continuous:
            2
        case .wheelTilt:
            3
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum PointerAxisRelativeDirection: Equatable, Sendable {
    case identical
    case inverted
    case unknown(UInt32)

    public init(rawValue directionRawValue: UInt32) {
        switch directionRawValue {
        case 0:
            self = .identical
        case 1:
            self = .inverted
        default:
            self = .unknown(directionRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .identical:
            0
        case .inverted:
            1
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public struct KeyboardModifierMask: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    public let rawValue: UInt32

    public init(rawValue modifierMaskRawValue: UInt32) {
        rawValue = modifierMaskRawValue
    }

    public var description: String {
        String(rawValue)
    }
}

public struct KeyboardLayoutGroup: RawRepresentable, Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    public let rawValue: UInt32

    public init(rawValue layoutGroupRawValue: UInt32) {
        rawValue = layoutGroupRawValue
    }

    public var description: String {
        String(rawValue)
    }
}
