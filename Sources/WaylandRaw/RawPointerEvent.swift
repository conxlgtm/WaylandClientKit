package enum RawPointerEvent: Equatable, Sendable {
    case enter(RawPointerEnter)
    case leave(RawPointerLeave)
    case motion(RawPointerMotion)
    case button(RawPointerButton)
    case axis(RawPointerAxisEvent)
}

package struct RawPointerEnter: Equatable, Sendable {
    package let serial: UInt32
    package let surfaceID: RawObjectID?
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(
        serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?, x eventX: WaylandFixed,
        y eventY: WaylandFixed
    ) {
        serial = eventSerial
        surfaceID = eventSurfaceID
        x = eventX
        y = eventY
    }
}

package struct RawPointerLeave: Equatable, Sendable {
    package let serial: UInt32
    package let surfaceID: RawObjectID?

    package init(serial eventSerial: UInt32, surfaceID eventSurfaceID: RawObjectID?) {
        serial = eventSerial
        surfaceID = eventSurfaceID
    }
}

package struct RawPointerMotion: Equatable, Sendable {
    package let time: UInt32
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(time eventTime: UInt32, x eventX: WaylandFixed, y eventY: WaylandFixed) {
        time = eventTime
        x = eventX
        y = eventY
    }
}

package struct RawPointerButton: Equatable, Sendable {
    package let serial: UInt32
    package let time: UInt32
    package let button: UInt32
    package let state: RawPointerButtonState

    package init(
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

package enum RawPointerAxisEvent: Equatable, Sendable {
    case axis(time: UInt32, axis: RawPointerAxis, value: WaylandFixed)
    case source(RawPointerAxisSource)
    case stop(time: UInt32, axis: RawPointerAxis)
    case discrete(axis: RawPointerAxis, value: Int32)
    case value120(axis: RawPointerAxis, value120: Int32)
    case relativeDirection(axis: RawPointerAxis, direction: RawPointerAxisRelativeDirection)
    case frame
}

package struct RawPointerButtonState: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    package static let released = Self(rawValue: 0)
    package static let pressed = Self(rawValue: 1)
}

package struct RawPointerAxis: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue axisRawValue: UInt32) {
        rawValue = axisRawValue
    }

    package static let verticalScroll = Self(rawValue: 0)
    package static let horizontalScroll = Self(rawValue: 1)
}

package struct RawPointerAxisSource: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue sourceRawValue: UInt32) {
        rawValue = sourceRawValue
    }

    package static let wheel = Self(rawValue: 0)
    package static let finger = Self(rawValue: 1)
    package static let continuous = Self(rawValue: 2)
    package static let wheelTilt = Self(rawValue: 3)
}

package struct RawPointerAxisRelativeDirection: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue directionRawValue: UInt32) {
        rawValue = directionRawValue
    }

    package static let identical = Self(rawValue: 0)
    package static let inverted = Self(rawValue: 1)
}
