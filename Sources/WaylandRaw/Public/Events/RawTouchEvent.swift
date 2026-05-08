package enum RawTouchEvent: Equatable, Sendable {
    case down(RawTouchDown)
    case up(RawTouchUp)
    case motion(RawTouchMotion)
    case frame
    case cancel
    case shape(RawTouchShape)
    case orientation(RawTouchOrientation)
}

package struct RawTouchID: Equatable, Hashable, Sendable, CustomStringConvertible,
    ExpressibleByIntegerLiteral
{
    package typealias IntegerLiteralType = Int32

    package let rawValue: Int32

    package init(rawValue touchIDRawValue: Int32) {
        rawValue = touchIDRawValue
    }

    package init(integerLiteral value: Int32) {
        self.init(rawValue: value)
    }

    package var description: String {
        String(rawValue)
    }
}

package struct RawTouchDown: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let surfaceID: RawObjectID?
    package let id: RawTouchID
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(
        serial eventSerial: UInt32,
        time eventTime: UInt32,
        surfaceID eventSurfaceID: RawObjectID?,
        id eventID: RawTouchID,
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

package struct RawTouchUp: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let id: RawTouchID

    package init(serial eventSerial: UInt32, time eventTime: UInt32, id eventID: RawTouchID) {
        serial = eventSerial
        time = eventTime
        id = eventID
    }
}

package struct RawTouchMotion: Equatable, Sendable {
    package let time: UInt32
    package let id: RawTouchID
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(
        time eventTime: UInt32,
        id eventID: RawTouchID,
        x eventX: WaylandFixed,
        y eventY: WaylandFixed
    ) {
        time = eventTime
        id = eventID
        x = eventX
        y = eventY
    }
}

package struct RawTouchShape: Equatable, Sendable {
    package let id: RawTouchID
    package let major: WaylandFixed
    package let minor: WaylandFixed

    package init(
        id touchID: RawTouchID,
        major touchMajor: WaylandFixed,
        minor touchMinor: WaylandFixed
    ) {
        id = touchID
        major = touchMajor
        minor = touchMinor
    }
}

package struct RawTouchOrientation: Equatable, Sendable {
    package let id: RawTouchID
    package let orientation: WaylandFixed

    package init(id touchID: RawTouchID, orientation touchOrientation: WaylandFixed) {
        id = touchID
        orientation = touchOrientation
    }
}
