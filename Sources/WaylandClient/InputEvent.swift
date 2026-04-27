import WaylandRaw

public struct InputEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let seatID: SeatID
    public let windowID: WindowID?
    public let kind: InputEventKind

    public init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: SeatID,
        windowID eventWindowID: WindowID?,
        kind eventKind: InputEventKind
    ) {
        sequence = eventSequence
        seatID = eventSeatID
        windowID = eventWindowID
        kind = eventKind
    }
}

public enum InputEventKind: Equatable, Sendable {
    case seat(SeatEvent)
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
    case entered(PointerLocation, serial: UInt32)
    case left(serial: UInt32)
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
    public let serial: UInt32
    public let time: UInt32
    public let button: UInt32
    public let state: ButtonState

    public init(
        serial eventSerial: UInt32,
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

public struct ButtonState: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let released = Self(rawValue: 0)
    public static let pressed = Self(rawValue: 1)
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
    case keymapChanged(KeyboardKeymapInfo)
    case entered(serial: UInt32, pressedKeys: [UInt32])
    case left(serial: UInt32)
    case key(KeyboardKeyEvent)
    case modifiers(KeyboardModifiers)
    case repeatInfo(KeyboardRepeatInfo)
}

public struct KeyboardKeymapInfo: Equatable, Sendable {
    public let format: KeyboardKeymapFormat
    public let size: UInt32

    public init(format keymapFormat: KeyboardKeymapFormat, size keymapSize: UInt32) {
        format = keymapFormat
        size = keymapSize
    }
}

public struct KeyboardKeymapFormat: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue formatRawValue: UInt32) {
        rawValue = formatRawValue
    }

    public static let noKeymap = Self(rawValue: 0)
    public static let xkbV1 = Self(rawValue: 1)
}

public struct KeyboardKeyEvent: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let rawKeycode: UInt32
    public let state: KeyState

    public init(
        serial eventSerial: UInt32,
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

public struct KeyState: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let released = Self(rawValue: 0)
    public static let pressed = Self(rawValue: 1)
    public static let repeated = Self(rawValue: 2)
}

public struct KeyboardModifiers: Equatable, Sendable {
    public let serial: UInt32
    public let depressed: UInt32
    public let latched: UInt32
    public let locked: UInt32
    public let group: UInt32

    public init(
        serial eventSerial: UInt32,
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

public struct KeyboardRepeatInfo: Equatable, Sendable {
    public let rate: Int32
    public let delay: Int32

    public init(rate repeatRate: Int32, delay repeatDelay: Int32) {
        rate = repeatRate
        delay = repeatDelay
    }
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
    public let serial: UInt32
    public let time: UInt32
    public let id: Int32
    public let location: PointerLocation

    public init(
        serial eventSerial: UInt32,
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
    public let serial: UInt32
    public let time: UInt32
    public let id: Int32

    public init(serial eventSerial: UInt32, time eventTime: UInt32, id eventID: Int32) {
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
