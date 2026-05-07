import WaylandRaw

package struct InterpretedKeyboardEvent: Equatable, Sendable {
    package let sequence: UInt64
    package let seatID: RawSeatID
    package let deviceID: RawInputDeviceID?
    package let kind: InterpretedKeyboardEventKind

    package init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: RawSeatID,
        deviceID eventDeviceID: RawInputDeviceID?,
        kind eventKind: InterpretedKeyboardEventKind
    ) {
        sequence = eventSequence
        seatID = eventSeatID
        deviceID = eventDeviceID
        kind = eventKind
    }
}

package enum InterpretedKeyboardEventKind: Equatable, Sendable {
    case keymap(InterpretedKeyboardKeymap)
    case key(InterpretedKeyboardKey)
    case modifiers(InterpretedKeyboardModifiers)
    case repeatInfo(InterpretedKeyboardRepeatInfo)
    case unavailable(KeyboardInterpretationUnavailable)
}

package struct InterpretedKeyboardKeymap: Equatable, Sendable {
    package let id: RawKeyboardKeymapID
    package let format: RawKeyboardKeymapFormat
    package let size: UInt32

    package init(
        id keymapID: RawKeyboardKeymapID,
        format keymapFormat: RawKeyboardKeymapFormat,
        size keymapSize: UInt32
    ) {
        id = keymapID
        format = keymapFormat
        size = keymapSize
    }
}

package struct InterpretedKeyboardKey: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let evdevKeycode: UInt32
    package let xkbKeycode: UInt32
    package let keysym: KeyboardKeysym
    package let interpretation: InterpretedKeyboardKeyInterpretation

    package init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        evdevKeycode eventEvdevKeycode: UInt32,
        xkbKeycode eventXKBKeycode: UInt32,
        keysym eventKeysym: KeyboardKeysym,
        interpretation eventInterpretation: InterpretedKeyboardKeyInterpretation
    ) {
        serial = eventSerial
        time = eventTime
        evdevKeycode = eventEvdevKeycode
        xkbKeycode = eventXKBKeycode
        keysym = eventKeysym
        interpretation = eventInterpretation
    }

    package var state: InterpretedKeyboardKeyState {
        interpretation.state
    }

    package var keysymName: String? {
        interpretation.keysymName
    }

    package var utf8: String? {
        interpretation.utf8
    }

    package var repeatCapability: KeyboardKeyRepeatCapability? {
        interpretation.repeatCapability
    }
}

package struct InterpretedKeyboardKeyState: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    package static let released = Self(rawValue: 0)
    package static let pressed = Self(rawValue: 1)
    package static let repeated = Self(rawValue: 2)
}

package enum InterpretedKeyboardKeyInterpretation: Equatable, Sendable {
    case released(keysymName: String?)
    case pressed(
        keysymName: String?,
        utf8: String?,
        repeatCapability: KeyboardKeyRepeatCapability
    )
    case repeated(keysymName: String?, utf8: String?)
    case unknown(state: InterpretedKeyboardKeyState, keysymName: String?)

    package init(
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

    package var state: InterpretedKeyboardKeyState {
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

    package var keysymName: String? {
        switch self {
        case .released(let keysymName),
            .pressed(let keysymName, _, _),
            .repeated(let keysymName, _),
            .unknown(_, let keysymName):
            keysymName
        }
    }

    package var utf8: String? {
        switch self {
        case .pressed(_, let utf8, _), .repeated(_, let utf8):
            utf8
        case .released, .unknown:
            nil
        }
    }

    package var repeatCapability: KeyboardKeyRepeatCapability? {
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

package enum KeyboardKeyRepeatCapability: Equatable, Sendable {
    case nonRepeating
    case repeating

    package init(keymapAllowsRepeat allowsRepeat: Bool) {
        self = allowsRepeat ? .repeating : .nonRepeating
    }
}

package struct KeyboardKeysym: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue keysymRawValue: UInt32) {
        rawValue = keysymRawValue
    }
}

package struct InterpretedKeyboardModifiers: Equatable, Sendable {
    package let serial: UInt32
    package let depressed: UInt32
    package let latched: UInt32
    package let locked: UInt32
    package let group: UInt32
    package let changedComponents: XKBStateComponents

    package init(
        serial eventSerial: UInt32,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32,
        changedComponents eventChangedComponents: XKBStateComponents
    ) {
        serial = eventSerial
        depressed = eventDepressed
        latched = eventLatched
        locked = eventLocked
        group = eventGroup
        changedComponents = eventChangedComponents
    }
}

package struct XKBStateComponents: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue componentsRawValue: UInt32) {
        rawValue = componentsRawValue
    }

    package static let modsDepressed = Self(rawValue: 1 << 0)
    package static let modsLatched = Self(rawValue: 1 << 1)
    package static let modsLocked = Self(rawValue: 1 << 2)
    package static let modsEffective = Self(rawValue: 1 << 3)
    package static let layoutDepressed = Self(rawValue: 1 << 4)
    package static let layoutLatched = Self(rawValue: 1 << 5)
    package static let layoutLocked = Self(rawValue: 1 << 6)
    package static let layoutEffective = Self(rawValue: 1 << 7)
    package static let leds = Self(rawValue: 1 << 8)
}

package enum InterpretedKeyboardRepeatInfo: Equatable, Sendable {
    case disabled
    case enabled(rate: RawKeyboardRepeatRate, delay: RawKeyboardRepeatDelay)

    package init(_ repeatInfo: RawKeyboardRepeatInfo) {
        switch repeatInfo {
        case .disabled:
            self = .disabled
        case .enabled(let rate, let delay):
            self = .enabled(rate: rate, delay: delay)
        }
    }
}

package struct KeyboardInterpretationUnavailable: Equatable, Sendable {
    package let reason: KeyboardInterpretationUnavailableReason

    package init(reason unavailableReason: KeyboardInterpretationUnavailableReason) {
        reason = unavailableReason
    }
}

package enum KeyboardInterpretationUnavailableReason: Equatable, Sendable {
    case missingDeviceID
    case noKeymap
    case unsupportedKeymapFormat(UInt32)
    case emptyKeymap
    case invalidKeymap
    case keymapReadFailed(RawKeyboardKeymapReadError)
    case missingKeymap
    case missingKeyboardState
    case invalidKeycode(UInt32)
    case nonKeyboardInputDevice(RawInputDeviceID)
    case mismatchedKeyboardSeat(expected: RawSeatID, actual: RawSeatID)
    case mismatchedKeyboardDevice(expected: RawInputDeviceID, actual: RawInputDeviceID)
}

package enum KeyboardInterpreterKeymapState: Equatable, Sendable {
    case missing
    case noKeymap(RawKeyboardKeymapID)
    case valid(RawKeyboardKeymapID)
    case unavailable(
        keymapID: RawKeyboardKeymapID?,
        reason: KeyboardInterpretationUnavailableReason
    )
}
