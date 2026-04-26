public enum RawTouchEvent: Equatable, Sendable {
    case down(RawTouchDown)
    case up(RawTouchUp)
    case motion(RawTouchMotion)
    case frame
    case cancel
    case shape(RawTouchShape)
    case orientation(RawTouchOrientation)
}

public struct RawTouchDown: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let surfaceID: RawObjectID?
    public let id: Int32
    public let x: WaylandFixed
    public let y: WaylandFixed

    public init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        surfaceID eventSurfaceID: RawObjectID?,
        id eventID: Int32,
        x eventX: WaylandFixed,
        y eventY: WaylandFixed
    ) {
        serial = eventSerial
        time = eventTime
        surfaceID = eventSurfaceID
        id = eventID
        x = eventX
        y = eventY
    }
}

public struct RawTouchUp: Equatable, Sendable {
    public let serial: UInt32
    public let time: UInt32
    public let id: Int32

    public init(serial eventSerial: UInt32, time eventTime: UInt32, id eventID: Int32) {
        serial = eventSerial
        time = eventTime
        id = eventID
    }
}

public struct RawTouchMotion: Equatable, Sendable {
    public let time: UInt32
    public let id: Int32
    public let x: WaylandFixed
    public let y: WaylandFixed

    public init(
        time eventTime: UInt32, id eventID: Int32, x eventX: WaylandFixed, y eventY: WaylandFixed
    ) {
        time = eventTime
        id = eventID
        x = eventX
        y = eventY
    }
}

public struct RawTouchShape: Equatable, Sendable {
    public let id: Int32
    public let major: WaylandFixed
    public let minor: WaylandFixed

    public init(id touchID: Int32, major touchMajor: WaylandFixed, minor touchMinor: WaylandFixed) {
        id = touchID
        major = touchMajor
        minor = touchMinor
    }
}

public struct RawTouchOrientation: Equatable, Sendable {
    public let id: Int32
    public let orientation: WaylandFixed

    public init(id touchID: Int32, orientation touchOrientation: WaylandFixed) {
        id = touchID
        orientation = touchOrientation
    }
}
