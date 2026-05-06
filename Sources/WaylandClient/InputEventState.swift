public enum ButtonState: Equatable, Sendable {
    case released
    case pressed
    case unknown(UInt32)

    public init(rawValue stateRawValue: UInt32) {
        switch stateRawValue {
        case 0:
            self = .released
        case 1:
            self = .pressed
        default:
            self = .unknown(stateRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .released:
            0
        case .pressed:
            1
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum KeyboardKeymapFormat: Equatable, Sendable {
    case noKeymap
    case xkbV1
    case unknown(UInt32)

    public init(rawValue formatRawValue: UInt32) {
        switch formatRawValue {
        case 0:
            self = .noKeymap
        case 1:
            self = .xkbV1
        default:
            self = .unknown(formatRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .noKeymap:
            0
        case .xkbV1:
            1
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum KeyState: Equatable, Sendable {
    case released
    case pressed
    case repeated
    case unknown(UInt32)

    public init(rawValue stateRawValue: UInt32) {
        switch stateRawValue {
        case 0:
            self = .released
        case 1:
            self = .pressed
        case 2:
            self = .repeated
        default:
            self = .unknown(stateRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .released:
            0
        case .pressed:
            1
        case .repeated:
            2
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum InterpretedKeyboardKeyState: Equatable, Sendable {
    case released
    case pressed
    case repeated
    case unknown(UInt32)

    public init(rawValue stateRawValue: UInt32) {
        switch stateRawValue {
        case 0:
            self = .released
        case 1:
            self = .pressed
        case 2:
            self = .repeated
        default:
            self = .unknown(stateRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .released:
            0
        case .pressed:
            1
        case .repeated:
            2
        case .unknown(let rawValue):
            rawValue
        }
    }
}
