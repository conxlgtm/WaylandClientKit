public struct InputEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let seatID: SeatID
    public let target: InputEventTarget
    public let kind: InputEventKind

    public init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: SeatID,
        target eventTarget: InputEventTarget,
        kind eventKind: InputEventKind
    ) {
        sequence = eventSequence
        seatID = eventSeatID
        target = eventTarget
        kind = eventKind
    }

    public init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: SeatID,
        windowID eventWindowID: WindowID?,
        kind eventKind: InputEventKind
    ) {
        self.init(
            sequence: eventSequence,
            seatID: eventSeatID,
            target: eventWindowID.map(InputEventTarget.window) ?? .display,
            kind: eventKind
        )
    }

    public var windowID: WindowID? {
        guard case .window(let windowID) = target else {
            return nil
        }

        return windowID
    }
}

public enum InputEventTarget: Equatable, Sendable {
    case display
    case window(WindowID)
    case unmanagedSurface
    case focusless
}

public enum InputEventKind: Equatable, Sendable {
    case seat(SeatEvent)
    case diagnostic(InputDiagnostic)
    case pointer(PointerEvent)
    case keyboard(KeyboardEvent)
    case touch(TouchEvent)
}

public enum SeatEvent: Equatable, Sendable {
    case changed(SeatStateSnapshot)
    case removed
}

public struct SeatStateSnapshot: Equatable, Sendable {
    public let advertisedCapabilities: SeatCapabilities
    public let activeCapabilities: SeatCapabilities
    public let name: String?

    public init(
        advertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        name seatName: String?
    ) {
        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities = seatActiveCapabilities
        name = seatName
    }
}

public enum PointerEvent: Equatable, Sendable {
    case entered(PointerLocation, serial: InputSerial)
    case left(serial: InputSerial)
    case moved(PointerLocation, time: UInt32)
    case button(PointerButtonEvent)
    case axis(PointerAxisEvent)
}

public struct PointerLocation: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x locationX: Double, y locationY: Double) {
        x = locationX
        y = locationY
    }
}

public struct PointerButtonEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let button: UInt32
    public let state: ButtonState

    public init(
        serial eventSerial: InputSerial,
        time eventTime: UInt32,
        button eventButton: UInt32,
        state eventState: ButtonState
    ) {
        serial = eventSerial
        time = eventTime
        button = eventButton
        state = eventState
    }
}

public enum PointerAxisEvent: Equatable, Sendable {
    case axis(time: UInt32, axis: PointerAxis, value: Double)
    case source(PointerAxisSource)
    case stop(time: UInt32, axis: PointerAxis)
    case discrete(axis: PointerAxis, value: Int32)
    case value120(axis: PointerAxis, value120: Int32)
    case relativeDirection(axis: PointerAxis, direction: PointerAxisRelativeDirection)
    case frame
}

public struct PointerAxis: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue axisRawValue: UInt32) {
        rawValue = axisRawValue
    }

    public static let verticalScroll = Self(rawValue: 0)
    public static let horizontalScroll = Self(rawValue: 1)
}

public struct PointerAxisSource: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue sourceRawValue: UInt32) {
        rawValue = sourceRawValue
    }

    public static let wheel = Self(rawValue: 0)
    public static let finger = Self(rawValue: 1)
    public static let continuous = Self(rawValue: 2)
    public static let wheelTilt = Self(rawValue: 3)
}

public struct PointerAxisRelativeDirection: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue directionRawValue: UInt32) {
        rawValue = directionRawValue
    }

    public static let identical = Self(rawValue: 0)
    public static let inverted = Self(rawValue: 1)
}

public enum KeyboardEvent: Equatable, Sendable {
    case raw(RawKeyboardEvent)
    case interpreted(InterpretedKeyboardEvent)
}

public enum RawKeyboardEvent: Equatable, Sendable {
    case keymapChanged(KeyboardKeymapInfo)
    case entered(serial: InputSerial, pressedKeys: [UInt32])
    case left(serial: InputSerial)
    case key(KeyboardKeyEvent)
    case modifiers(KeyboardModifiers)
    case repeatInfo(KeyboardRepeatInfo)
}

public enum InterpretedKeyboardEvent: Equatable, Sendable {
    case keymap(InterpretedKeyboardKeymapInfo)
    case key(InterpretedKeyboardKeyEvent)
    case modifiers(InterpretedKeyboardModifiers)
    case repeatInfo(InterpretedKeyboardRepeatInfo)
    case unavailable(KeyboardInterpretationUnavailable)
}

public struct InterpretedKeyboardKeymapInfo: Equatable, Sendable {
    public let format: KeyboardKeymapFormat
    public let size: UInt32

    public init(format keymapFormat: KeyboardKeymapFormat, size keymapSize: UInt32) {
        format = keymapFormat
        size = keymapSize
    }
}

public struct KeyboardKeymapInfo: Equatable, Sendable {
    public let format: KeyboardKeymapFormat
    public let size: UInt32

    public init(format keymapFormat: KeyboardKeymapFormat, size keymapSize: UInt32) {
        format = keymapFormat
        size = keymapSize
    }
}

public struct KeyboardKeyEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let rawKeycode: UInt32
    public let state: KeyState

    public init(
        serial eventSerial: InputSerial,
        time eventTime: UInt32,
        rawKeycode eventRawKeycode: UInt32,
        state eventState: KeyState
    ) {
        serial = eventSerial
        time = eventTime
        rawKeycode = eventRawKeycode
        state = eventState
    }
}

public struct InterpretedKeyboardKeyEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let rawKeycode: UInt32
    public let xkbKeycode: UInt32
    public let state: InterpretedKeyboardKeyState
    public let keysym: KeyboardKeysym
    public let keysymName: String?
    public let utf8: String?
    public let repeats: Bool

    public init(
        serial eventSerial: InputSerial,
        time eventTime: UInt32,
        rawKeycode eventRawKeycode: UInt32,
        xkbKeycode eventXKBKeycode: UInt32,
        state eventState: InterpretedKeyboardKeyState,
        keysym eventKeysym: KeyboardKeysym,
        keysymName eventKeysymName: String?,
        utf8 eventUTF8: String?,
        repeats eventRepeats: Bool
    ) {
        serial = eventSerial
        time = eventTime
        rawKeycode = eventRawKeycode
        xkbKeycode = eventXKBKeycode
        state = eventState
        keysym = eventKeysym
        keysymName = eventKeysymName
        utf8 = eventUTF8
        repeats = eventRepeats
    }
}

public struct KeyboardKeysym: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue keysymRawValue: UInt32) {
        rawValue = keysymRawValue
    }
}

public struct KeyboardModifiers: Equatable, Sendable {
    public let serial: InputSerial
    public let depressed: UInt32
    public let latched: UInt32
    public let locked: UInt32
    public let group: UInt32

    public init(
        serial eventSerial: InputSerial,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32
    ) {
        serial = eventSerial
        depressed = eventDepressed
        latched = eventLatched
        locked = eventLocked
        group = eventGroup
    }
}

public struct InterpretedKeyboardModifiers: Equatable, Sendable {
    public let serial: InputSerial
    public let depressed: UInt32
    public let latched: UInt32
    public let locked: UInt32
    public let group: UInt32
    public let changedComponents: KeyboardModifierStateComponents

    public init(
        serial eventSerial: InputSerial,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32,
        changedComponents eventChangedComponents: KeyboardModifierStateComponents
    ) {
        serial = eventSerial
        depressed = eventDepressed
        latched = eventLatched
        locked = eventLocked
        group = eventGroup
        changedComponents = eventChangedComponents
    }
}

public struct KeyboardModifierStateComponents: OptionSet, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue componentsRawValue: UInt32) {
        rawValue = componentsRawValue
    }

    public static let modsDepressed = Self(rawValue: 1 << 0)
    public static let modsLatched = Self(rawValue: 1 << 1)
    public static let modsLocked = Self(rawValue: 1 << 2)
    public static let modsEffective = Self(rawValue: 1 << 3)
    public static let layoutDepressed = Self(rawValue: 1 << 4)
    public static let layoutLatched = Self(rawValue: 1 << 5)
    public static let layoutLocked = Self(rawValue: 1 << 6)
    public static let layoutEffective = Self(rawValue: 1 << 7)
    public static let leds = Self(rawValue: 1 << 8)
}

public struct KeyboardRepeatInfo: Equatable, Sendable {
    public let rate: Int32
    public let delay: Int32

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
}

public struct InterpretedKeyboardRepeatInfo: Equatable, Sendable {
    public let rate: Int32
    public let delay: Int32

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
}

public struct KeyboardInterpretationUnavailable: Equatable, Sendable {
    public let reason: KeyboardInterpretationUnavailableReason

    public init(reason unavailableReason: KeyboardInterpretationUnavailableReason) {
        reason = unavailableReason
    }
}

public enum KeyboardInterpretationUnavailableReason: Equatable, Sendable {
    case missingDeviceID
    case noKeymap
    case unsupportedKeymapFormat(UInt32)
    case emptyKeymap
    case invalidKeymap
    case keymapReadFailed(KeymapReadFailure)
    case missingKeymap
    case missingKeyboardState
    case invalidKeycode(UInt32)
    case nonKeyboardInputDevice
    case mismatchedKeyboardSeat(expected: SeatID, actual: SeatID)
    case mismatchedKeyboardDevice
}

public enum TouchEvent: Equatable, Sendable {
    case down(TouchDownEvent)
    case up(TouchUpEvent)
    case motion(TouchMotionEvent)
    case frame
    case cancel
    case shape(TouchShapeEvent)
    case orientation(TouchOrientationEvent)
}

public struct TouchDownEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let id: Int32
    public let location: PointerLocation

    public init(
        serial eventSerial: InputSerial,
        time eventTime: UInt32,
        id eventID: Int32,
        location eventLocation: PointerLocation
    ) {
        serial = eventSerial
        time = eventTime
        id = eventID
        location = eventLocation
    }
}

public struct TouchUpEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: UInt32
    public let id: Int32

    public init(serial eventSerial: InputSerial, time eventTime: UInt32, id eventID: Int32) {
        serial = eventSerial
        time = eventTime
        id = eventID
    }
}

public struct TouchMotionEvent: Equatable, Sendable {
    public let time: UInt32
    public let id: Int32
    public let location: PointerLocation

    public init(time eventTime: UInt32, id eventID: Int32, location eventLocation: PointerLocation)
    {
        time = eventTime
        id = eventID
        location = eventLocation
    }
}

public struct TouchShapeEvent: Equatable, Sendable {
    public let id: Int32
    public let major: Double
    public let minor: Double

    public init(id touchID: Int32, major touchMajor: Double, minor touchMinor: Double) {
        id = touchID
        major = touchMajor
        minor = touchMinor
    }
}

public struct TouchOrientationEvent: Equatable, Sendable {
    public let id: Int32
    public let orientation: Double

    public init(id touchID: Int32, orientation touchOrientation: Double) {
        id = touchID
        orientation = touchOrientation
    }
}
