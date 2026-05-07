public struct InterpretedKeyboardKeyEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let rawKeycode: UInt32
    public let xkbKeycode: UInt32
    public let keysym: KeyboardKeysym
    public let interpretation: InterpretedKeyboardKeyInterpretation

    public init(
        serial eventSerial: InputSerial,
        time eventTime: UInt32,
        rawKeycode eventRawKeycode: UInt32,
        xkbKeycode eventXKBKeycode: UInt32,
        keysym eventKeysym: KeyboardKeysym,
        interpretation eventInterpretation: InterpretedKeyboardKeyInterpretation
    ) {
        serial = eventSerial
        time = eventTime
        rawKeycode = eventRawKeycode
        xkbKeycode = eventXKBKeycode
        keysym = eventKeysym
        interpretation = eventInterpretation
    }

    public var state: InterpretedKeyboardKeyState {
        interpretation.state
    }

    public var keysymName: String? {
        interpretation.keysymName
    }

    public var utf8: String? {
        interpretation.utf8
    }

    public var repeatCapability: KeyboardKeyRepeatCapability? {
        interpretation.repeatCapability
    }
}

public enum InterpretedKeyboardKeyInterpretation: Equatable, Sendable {
    case released(keysymName: String?)
    case pressed(
        keysymName: String?,
        utf8: String?,
        repeatCapability: KeyboardKeyRepeatCapability
    )
    case repeated(keysymName: String?, utf8: String?)
    case unknown(state: InterpretedKeyboardKeyState, keysymName: String?)

    public init(
        state keyState: InterpretedKeyboardKeyState,
        keysymName keyKeysymName: String?,
        utf8 keyUTF8: String?,
        repeatCapability keyRepeatCapability: KeyboardKeyRepeatCapability
    ) {
        switch keyState {
        case .released:
            self = .released(keysymName: keyKeysymName)
        case .pressed:
            self = .pressed(
                keysymName: keyKeysymName,
                utf8: keyUTF8,
                repeatCapability: keyRepeatCapability
            )
        case .repeated:
            self = .repeated(keysymName: keyKeysymName, utf8: keyUTF8)
        default:
            self = .unknown(state: keyState, keysymName: keyKeysymName)
        }
    }

    public var state: InterpretedKeyboardKeyState {
        switch self {
        case .released:
            .released
        case .pressed:
            .pressed
        case .repeated:
            .repeated
        case .unknown(let state, _):
            state
        }
    }

    public var keysymName: String? {
        switch self {
        case .released(let keysymName),
            .pressed(let keysymName, _, _),
            .repeated(let keysymName, _),
            .unknown(_, let keysymName):
            keysymName
        }
    }

    public var utf8: String? {
        switch self {
        case .pressed(_, let utf8, _), .repeated(_, let utf8):
            utf8
        case .released, .unknown:
            nil
        }
    }

    public var repeatCapability: KeyboardKeyRepeatCapability? {
        switch self {
        case .pressed(_, _, let repeatCapability):
            repeatCapability
        case .repeated:
            .repeating
        case .released, .unknown:
            nil
        }
    }
}

public enum KeyboardKeyRepeatCapability: Equatable, Sendable {
    case nonRepeating
    case repeating
}
