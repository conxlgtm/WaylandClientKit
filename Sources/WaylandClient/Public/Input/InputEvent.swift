// swiftlint:disable file_length

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

    public var windowID: WindowID? {
        guard case .surface(let surface) = target else {
            return nil
        }

        return surface.windowID
    }

    public var popup: PopupSurfaceIdentity? {
        guard case .surface(.popup(let popup, _)) = target else {
            return nil
        }

        return popup
    }
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

public enum PointerEvent: Equatable, Sendable {
    case entered(PointerLocation, serial: InputSerial)
    case left(serial: InputSerial)
    case moved(PointerLocation, time: WaylandTimestampMilliseconds)
    case button(PointerButtonEvent)
    case axis(PointerAxisEvent)
    case relativeMotion(RelativePointerMotionEvent)
    case constraintLifecycle(PointerConstraintLifecycleEvent)
}

public struct PointerLocation: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x locationX: Double, y locationY: Double) {
        x = locationX
        y = locationY
    }
}

public struct PointerDelta: Equatable, Sendable {
    public let dx: Double
    public let dy: Double

    public init(dx pointerDX: Double, dy pointerDY: Double) {
        dx = pointerDX
        dy = pointerDY
    }
}

public struct RelativePointerMotionEvent: Equatable, Sendable {
    public let time: WaylandTimestampMicroseconds
    public let delta: PointerDelta
    public let unacceleratedDelta: PointerDelta

    public init(
        time eventTime: WaylandTimestampMicroseconds,
        delta eventDelta: PointerDelta,
        unacceleratedDelta eventUnacceleratedDelta: PointerDelta
    ) {
        time = eventTime
        delta = eventDelta
        unacceleratedDelta = eventUnacceleratedDelta
    }
}

public enum PointerConstraintKind: Equatable, Hashable, Sendable {
    case locked
    case confined
}

public struct PointerConstraintID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt64
    public let kind: PointerConstraintKind

    public init(rawValue constraintRawValue: UInt64, kind constraintKind: PointerConstraintKind) {
        rawValue = constraintRawValue
        kind = constraintKind
    }

    public var description: String {
        switch kind {
        case .locked:
            "locked-pointer-\(rawValue)"
        case .confined:
            "confined-pointer-\(rawValue)"
        }
    }
}

public enum PointerConstraintLifecycleEvent: Equatable, Sendable {
    case activated(PointerConstraintID)
    case inactivePersistent(PointerConstraintID)
    case defunctOneShot(PointerConstraintID)
}

public struct PointerButtonEvent: Equatable, Sendable {
    public let serial: InputSerial
    public let time: WaylandTimestampMilliseconds
    public let button: PointerButtonCode
    public let state: ButtonState

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        button eventButton: PointerButtonCode,
        state eventState: ButtonState
    ) {
        serial = eventSerial
        time = eventTime
        button = eventButton
        state = eventState
    }
}

public enum PointerAxisEvent: Equatable, Sendable {
    case axis(time: WaylandTimestampMilliseconds, axis: PointerAxis, value: Double)
    case source(PointerAxisSource)
    case stop(time: WaylandTimestampMilliseconds, axis: PointerAxis)
    case discrete(axis: PointerAxis, value: PointerAxisDiscreteStep)
    case value120(axis: PointerAxis, value120: PointerAxisValue120)
    case relativeDirection(axis: PointerAxis, direction: PointerAxisRelativeDirection)
    case frame
}

public enum KeyboardEvent: Equatable, Sendable {
    case raw(RawKeyboardEvent)
    case interpreted(InterpretedKeyboardEvent)
}

public enum RawKeyboardEvent: Equatable, Sendable {
    case keymapChanged(KeyboardKeymapInfo)
    case entered(serial: InputSerial, pressedKeys: [EvdevKeycode])
    case left(serial: InputSerial)
    case key(KeyboardKeyEvent)
    case modifiers(KeyboardModifiers)
    case repeatInfo(KeyboardRepeatPolicy)
}

public enum InterpretedKeyboardEvent: Equatable, Sendable {
    case keymap(InterpretedKeyboardKeymapInfo)
    case key(InterpretedKeyboardKeyEvent)
    case modifiers(InterpretedKeyboardModifiers)
    case repeatInfo(KeyboardRepeatPolicy)
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
    public let time: WaylandTimestampMilliseconds
    public let rawKeycode: EvdevKeycode
    public let state: KeyState

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        rawKeycode eventRawKeycode: EvdevKeycode,
        state eventState: KeyState
    ) {
        serial = eventSerial
        time = eventTime
        rawKeycode = eventRawKeycode
        state = eventState
    }
}

public struct KeyboardKeysym: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue keysymRawValue: UInt32) {
        rawValue = keysymRawValue
    }

    public static let noSymbol = Self(rawValue: 0)
}

public struct KeyboardModifiers: Equatable, Sendable {
    public let serial: InputSerial
    public let depressed: KeyboardModifierMask
    public let latched: KeyboardModifierMask
    public let locked: KeyboardModifierMask
    public let group: KeyboardLayoutGroup

    public init(
        serial eventSerial: InputSerial,
        depressed eventDepressed: UInt32,
        latched eventLatched: UInt32,
        locked eventLocked: UInt32,
        group eventGroup: UInt32
    ) {
        serial = eventSerial
        depressed = KeyboardModifierMask(rawValue: eventDepressed)
        latched = KeyboardModifierMask(rawValue: eventLatched)
        locked = KeyboardModifierMask(rawValue: eventLocked)
        group = KeyboardLayoutGroup(rawValue: eventGroup)
    }

    public init(
        serial eventSerial: InputSerial,
        depressed eventDepressed: KeyboardModifierMask,
        latched eventLatched: KeyboardModifierMask,
        locked eventLocked: KeyboardModifierMask,
        group eventGroup: KeyboardLayoutGroup
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
    public let depressed: KeyboardModifierMask
    public let latched: KeyboardModifierMask
    public let locked: KeyboardModifierMask
    public let group: KeyboardLayoutGroup
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
        depressed = KeyboardModifierMask(rawValue: eventDepressed)
        latched = KeyboardModifierMask(rawValue: eventLatched)
        locked = KeyboardModifierMask(rawValue: eventLocked)
        group = KeyboardLayoutGroup(rawValue: eventGroup)
        changedComponents = eventChangedComponents
    }

    public init(
        serial eventSerial: InputSerial,
        depressed eventDepressed: KeyboardModifierMask,
        latched eventLatched: KeyboardModifierMask,
        locked eventLocked: KeyboardModifierMask,
        group eventGroup: KeyboardLayoutGroup,
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

public enum KeyboardRepeatPolicy: Equatable, Sendable {
    case disabled
    case enabled(rate: KeyboardRepeatRate, delay: KeyboardRepeatDelay)

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) throws {
        guard repeatDelay >= 0 else {
            throw KeyboardRepeatPolicyError.negativeDelay(rate: repeatRate, delay: repeatDelay)
        }
        guard repeatRate >= 0 else {
            throw KeyboardRepeatPolicyError.negativeRate(rate: repeatRate, delay: repeatDelay)
        }
        guard repeatRate > 0 else {
            self = .disabled
            return
        }

        self = .enabled(
            rate: KeyboardRepeatRate(unchecked: repeatRate),
            delay: KeyboardRepeatDelay(unchecked: repeatDelay)
        )
    }

    public var rate: Int32 {
        switch self {
        case .disabled:
            0
        case .enabled(let rate, _):
            rate.rawValue
        }
    }

    public var delayMilliseconds: Int32? {
        switch self {
        case .disabled:
            nil
        case .enabled(_, let delay):
            delay.rawValue
        }
    }
}

public struct KeyboardRepeatRate: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ value: Int32) throws {
        guard value > 0 else {
            throw KeyboardRepeatPolicyError.nonPositiveRate(value)
        }

        rawValue = value
    }

    package init(unchecked value: Int32) {
        precondition(value > 0, "keyboard repeat rate must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct KeyboardRepeatDelay: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ value: Int32) throws {
        guard value >= 0 else {
            throw KeyboardRepeatPolicyError.negativeDelay(rate: 0, delay: value)
        }

        rawValue = value
    }

    package init(unchecked value: Int32) {
        precondition(value >= 0, "keyboard repeat delay must be non-negative")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum KeyboardRepeatPolicyError: Error, Equatable, Sendable, CustomStringConvertible {
    case nonPositiveRate(Int32)
    case negativeRate(rate: Int32, delay: Int32)
    case negativeDelay(rate: Int32, delay: Int32)

    public var description: String {
        switch self {
        case .nonPositiveRate(let value):
            "keyboard repeat rate must be positive, got \(value)"
        case .negativeRate(let rate, let delay):
            "invalid keyboard repeat info: negative rate \(rate), delay \(delay)"
        case .negativeDelay(let rate, let delay):
            "invalid keyboard repeat info: rate \(rate), negative delay \(delay)"
        }
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
    case composeTableUnavailable(locale: String)
    case invalidComposeConfiguration
    case composeStateCreationFailed
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
    public let time: WaylandTimestampMilliseconds
    public let id: TouchID
    public let location: PointerLocation

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        id eventID: TouchID,
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
    public let time: WaylandTimestampMilliseconds
    public let id: TouchID

    public init(
        serial eventSerial: InputSerial,
        time eventTime: WaylandTimestampMilliseconds,
        id eventID: TouchID
    ) {
        serial = eventSerial
        time = eventTime
        id = eventID
    }
}

public struct TouchMotionEvent: Equatable, Sendable {
    public let time: WaylandTimestampMilliseconds
    public let id: TouchID
    public let location: PointerLocation

    public init(
        time eventTime: WaylandTimestampMilliseconds,
        id eventID: TouchID,
        location eventLocation: PointerLocation
    ) {
        time = eventTime
        id = eventID
        location = eventLocation
    }
}

public struct TouchShapeEvent: Equatable, Sendable {
    public let id: TouchID
    public let major: Double
    public let minor: Double

    public init(id touchID: TouchID, major touchMajor: Double, minor touchMinor: Double) {
        id = touchID
        major = touchMajor
        minor = touchMinor
    }
}

public struct TouchOrientationEvent: Equatable, Sendable {
    public let id: TouchID
    public let orientation: Double

    public init(id touchID: TouchID, orientation touchOrientation: Double) {
        id = touchID
        orientation = touchOrientation
    }
}
