public struct InterpretedKeyboardKeyEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: WaylandTimestampMilliseconds
    public let rawKeycode: EvdevKeycode
    public let xkbKeycode: XKBKeycode
    public let symbolResolution: KeyboardSymbolResolution
    public let interpretation: InterpretedKeyboardKeyInterpretation
    public let text: KeyboardTextResult

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        rawKeycode eventRawKeycode: EvdevKeycode,
        xkbKeycode eventXKBKeycode: XKBKeycode,
        keysym eventKeysym: KeyboardKeysym,
        interpretation eventInterpretation: InterpretedKeyboardKeyInterpretation,
        text eventText: KeyboardTextResult = .none
    ) {
        self.init(
            serial: eventSerial,
            time: eventTime,
            rawKeycode: eventRawKeycode,
            xkbKeycode: eventXKBKeycode,
            symbolResolution: .single(eventKeysym),
            interpretation: eventInterpretation,
            text: eventText
        )
    }

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        rawKeycode eventRawKeycode: EvdevKeycode,
        xkbKeycode eventXKBKeycode: XKBKeycode,
        symbolResolution eventSymbolResolution: KeyboardSymbolResolution,
        interpretation eventInterpretation: InterpretedKeyboardKeyInterpretation,
        text eventText: KeyboardTextResult = .none
    ) {
        serial = eventSerial
        time = eventTime
        rawKeycode = eventRawKeycode
        xkbKeycode = eventXKBKeycode
        symbolResolution = eventSymbolResolution
        interpretation = eventInterpretation
        text = eventText
    }

    public var keysym: KeyboardKeysym {
        symbolResolution.primary
    }

    public var keySymbols: [KeyboardKeysym] {
        symbolResolution.all
    }

    public var primaryKeySymbol: KeyboardKeysym {
        symbolResolution.primary
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

    public var keyText: String? {
        interpretation.utf8
    }

    public var repeatCapability: KeyboardKeyRepeatCapability? {
        interpretation.repeatCapability
    }
}

public enum KeyboardSymbolResolutionError: Error, Equatable, Sendable {
    case emptySymbols
    case primaryNotFirst(primary: KeyboardKeysym, first: KeyboardKeysym)
}

public struct KeyboardSymbolResolution: Equatable, Sendable {
    public let primary: KeyboardKeysym
    public let all: [KeyboardKeysym]

    public init(
        primary primaryKeysym: KeyboardKeysym,
        all keysyms: [KeyboardKeysym]
    ) throws(KeyboardSymbolResolutionError) {
        guard let first = keysyms.first else {
            throw .emptySymbols
        }
        guard first == primaryKeysym else {
            throw .primaryNotFirst(primary: primaryKeysym, first: first)
        }

        primary = primaryKeysym
        all = keysyms
    }

    public static func single(_ keysym: KeyboardKeysym) -> Self {
        Self(uncheckedPrimary: keysym, all: [keysym])
    }

    public static func resolved(_ keysyms: [KeyboardKeysym]) -> Self {
        guard let first = keysyms.first else {
            return .single(.noSymbol)
        }
        return Self(uncheckedPrimary: first, all: keysyms)
    }

    private init(uncheckedPrimary primaryKeysym: KeyboardKeysym, all keysyms: [KeyboardKeysym]) {
        primary = primaryKeysym
        all = keysyms
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

public enum KeyboardTextResult: Equatable, Sendable {
    case none
    case composing(KeyboardComposeProgress)
    case committed(KeyboardTextCommit)
    case cancelled(KeyboardComposeCancellation)

    public var committedString: String? {
        switch self {
        case .committed(let commit):
            commit.string
        case .cancelled(let cancellation):
            cancellation.fallbackCommit?.string
        case .none, .composing:
            nil
        }
    }
}

public struct KeyboardTextCommit: Equatable, Sendable {
    public let string: String
    public let source: KeyboardTextSource
    public let resultKeysym: KeyboardKeysym?
    public let resultKeysymName: String?

    public init(
        string commitString: String,
        source commitSource: KeyboardTextSource,
        resultKeysym commitResultKeysym: KeyboardKeysym?,
        resultKeysymName commitResultKeysymName: String?
    ) {
        string = commitString
        source = commitSource
        resultKeysym = commitResultKeysym
        resultKeysymName = commitResultKeysymName
    }
}

public enum KeyboardTextSource: Equatable, Sendable {
    case xkbKey
    case compose
    case composeCancellationFallback
}

public struct KeyboardComposeProgress: Equatable, Sendable {
    public let startedBy: KeyboardKeysym?
    public let startedByName: String?

    public init(startedBy keysym: KeyboardKeysym?, startedByName keysymName: String?) {
        startedBy = keysym
        startedByName = keysymName
    }
}

public struct KeyboardComposeCancellation: Equatable, Sendable {
    public let cancellingKeysym: KeyboardKeysym?
    public let cancellingKeysymName: String?
    public let fallbackCommit: KeyboardTextCommit?

    public init(
        cancellingKeysym keysym: KeyboardKeysym?,
        cancellingKeysymName keysymName: String?,
        fallbackCommit cancellationFallbackCommit: KeyboardTextCommit?
    ) {
        cancellingKeysym = keysym
        cancellingKeysymName = keysymName
        fallbackCommit = cancellationFallbackCommit
    }
}
