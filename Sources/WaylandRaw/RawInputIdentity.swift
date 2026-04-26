public struct RawSeatID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue seatRawValue: UInt32) {
        rawValue = seatRawValue
    }

    public var description: String {
        "seat-\(rawValue)"
    }
}

public struct RawInputDeviceID: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: Hashable, Sendable, CustomStringConvertible {
        case pointer
        case keyboard
        case touch

        public var description: String {
            switch self {
            case .pointer:
                "pointer"
            case .keyboard:
                "keyboard"
            case .touch:
                "touch"
            }
        }
    }

    public let seatID: RawSeatID
    public let kind: Kind
    public let generation: UInt64

    public init(
        seatID deviceSeatID: RawSeatID,
        kind deviceKind: Kind,
        generation deviceGeneration: UInt64
    ) {
        seatID = deviceSeatID
        kind = deviceKind
        generation = deviceGeneration
    }

    public var description: String {
        "\(seatID).\(kind)-\(generation)"
    }
}
