package struct RawInputDeviceID: Hashable, Sendable, CustomStringConvertible {
    public enum Kind: Hashable, Sendable, CustomStringConvertible {
        case pointer
        case keyboard
        case touch
        case tablet

        package var description: String {
            switch self {
            case .pointer:
                "pointer"
            case .keyboard:
                "keyboard"
            case .touch:
                "touch"
            case .tablet:
                "tablet"
            }
        }
    }

    package let seatID: RawSeatID
    package let kind: Kind
    package let generation: UInt64

    package init(
        seatID deviceSeatID: RawSeatID,
        kind deviceKind: Kind,
        generation deviceGeneration: UInt64
    ) {
        seatID = deviceSeatID
        kind = deviceKind
        generation = deviceGeneration
    }

    package var description: String {
        "\(seatID).\(kind)-\(generation)"
    }
}
