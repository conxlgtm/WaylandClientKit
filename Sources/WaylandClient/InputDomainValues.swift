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
