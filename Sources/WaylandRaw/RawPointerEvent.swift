public enum RawPointerEvent: Equatable, Sendable {
    case enter(RawPointerEnter)
    case leave(RawPointerLeave)
    case motion(RawPointerMotion)
    case button(RawPointerButton)
    case axis(RawPointerAxisEvent)
}

public struct RawPointerEnter: Equatable, Sendable {
    public let serial: UInt32
    public let surfaceID: RawObjectID?
    public let x: WaylandFixed
    public let y: WaylandFixed

    public init(
        serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?, x eventX: WaylandFixed,
        y eventY: WaylandFixed
    ) {
        serial = eventSerial
        surfaceID = eventSurfaceID
        x = eventX
        y = eventY
    }
}

public struct RawPointerLeave: Equatable, Sendable {
    public let serial: UInt32
    public let surfaceID: RawObjectID?

    public init(serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?) {
        serial = eventSerial
        surfaceID = eventSurfaceID
    }
}

public struct RawPointerMotion: Equatable, Sendable {
    public let time: UInt32
    public let x: WaylandFixed
    public let y: WaylandFixed

    public init(time eventTime: UInt32, x eventX: WaylandFixed, y eventY: WaylandFixed) {
        time = eventTime
        x = eventX
        y = eventY
    }
}

public struct RawPointerButton: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let button: UInt32
    public let state: RawPointerButtonState

    public init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        button eventButton: UInt32,
        state eventState: RawPointerButtonState
    ) {
        serial = eventSerial
        time = eventTime
        button = eventButton
        state = eventState
    }
}

public enum RawPointerAxisEvent: Equatable, Sendable {
    case axis(time: UInt32, axis: RawPointerAxis, value: WaylandFixed)
    case source(RawPointerAxisSource)
    case stop(time: UInt32, axis: RawPointerAxis)
    case discrete(axis: RawPointerAxis, value: Int32)
    case value120(axis: RawPointerAxis, value120: Int32)
    case relativeDirection(axis: RawPointerAxis, direction: RawPointerAxisRelativeDirection)
    case frame
}

public struct RawPointerButtonState: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let released = Self(rawValue: 0)
    public static let pressed = Self(rawValue: 1)
}

public struct RawPointerAxis: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue axisRawValue: UInt32) {
        rawValue = axisRawValue
    }

    public static let verticalScroll = Self(rawValue: 0)
    public static let horizontalScroll = Self(rawValue: 1)
}

public struct RawPointerAxisSource: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue sourceRawValue: UInt32) {
        rawValue = sourceRawValue
    }

    public static let wheel = Self(rawValue: 0)
    public static let finger = Self(rawValue: 1)
    public static let continuous = Self(rawValue: 2)
    public static let wheelTilt = Self(rawValue: 3)
}

public struct RawPointerAxisRelativeDirection: Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue directionRawValue: UInt32) {
        rawValue = directionRawValue
    }

    public static let identical = Self(rawValue: 0)
    public static let inverted = Self(rawValue: 1)
}
