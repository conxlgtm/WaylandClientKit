package enum RawTabletEvent: Equatable, Sendable {
    case tabletAdded(RawTabletIdentity)
    case toolAdded(RawTabletToolIdentity)
    case padAdded(RawTabletPadIdentity)
    case tablet(RawTabletDeviceEvent)
    case tool(RawTabletToolEvent)
    case pad(RawTabletPadEvent)
}

package enum RawTabletDeviceEvent: Equatable, Sendable {
    case name(RawTabletIdentity, String)
    case id(RawTabletIdentity, vendorID: UInt32, productID: UInt32)
    case path(RawTabletIdentity, String)
    case done(RawTabletIdentity)
    case removed(RawTabletIdentity)
    case busType(RawTabletIdentity, RawTabletBusType)
}

package struct RawTabletBusType: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue busTypeRawValue: UInt32) {
        rawValue = busTypeRawValue
    }

    package static let usb = Self(rawValue: 3)
    package static let bluetooth = Self(rawValue: 5)
    package static let virtual = Self(rawValue: 6)
    package static let serial = Self(rawValue: 17)
    package static let i2c = Self(rawValue: 24)
}

package enum RawTabletToolEvent: Equatable, Sendable {
    case type(RawTabletToolIdentity, RawTabletToolType)
    case hardwareSerial(RawTabletToolIdentity, UInt64)
    case hardwareIDWacom(RawTabletToolIdentity, UInt64)
    case capability(RawTabletToolIdentity, RawTabletToolCapability)
    case done(RawTabletToolIdentity)
    case removed(RawTabletToolIdentity)
    case proximityIn(RawTabletToolProximityIn)
    case proximityOut(RawTabletToolIdentity)
    case down(RawTabletToolIdentity, serial: UInt32)
    case up(RawTabletToolIdentity)
    case motion(RawTabletToolIdentity, x: WaylandFixed, y: WaylandFixed)
    case pressure(RawTabletToolIdentity, UInt32)
    case distance(RawTabletToolIdentity, UInt32)
    case tilt(RawTabletToolIdentity, x: WaylandFixed, y: WaylandFixed)
    case rotation(RawTabletToolIdentity, degrees: WaylandFixed)
    case slider(RawTabletToolIdentity, position: Int32)
    case wheel(RawTabletToolIdentity, degrees: WaylandFixed, clicks: Int32)
    case button(RawTabletToolButton)
    case frame(RawTabletToolIdentity, time: UInt32)
}

package struct RawTabletToolType: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue typeRawValue: UInt32) {
        rawValue = typeRawValue
    }

    package static let pen = Self(rawValue: 0x140)
    package static let eraser = Self(rawValue: 0x141)
    package static let brush = Self(rawValue: 0x142)
    package static let pencil = Self(rawValue: 0x143)
    package static let airbrush = Self(rawValue: 0x144)
    package static let finger = Self(rawValue: 0x145)
    package static let mouse = Self(rawValue: 0x146)
    package static let lens = Self(rawValue: 0x147)
}

package struct RawTabletToolCapability: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package init(rawValue capabilityRawValue: UInt32) {
        rawValue = capabilityRawValue
    }

    package static let tilt = Self(rawValue: 1)
    package static let pressure = Self(rawValue: 2)
    package static let distance = Self(rawValue: 3)
    package static let rotation = Self(rawValue: 4)
    package static let slider = Self(rawValue: 5)
    package static let wheel = Self(rawValue: 6)
}

package struct RawTabletToolProximityIn: Equatable, Sendable {
    package let tool: RawTabletToolIdentity
    package let serial: UInt32
    package let tablet: RawTabletIdentity
    package let surfaceID: RawObjectID?

    package init(
        tool toolIdentity: RawTabletToolIdentity,
        serial eventSerial: UInt32,
        tablet tabletIdentity: RawTabletIdentity,
        surfaceID eventSurfaceID: RawObjectID?
    ) {
        tool = toolIdentity
        serial = eventSerial
        tablet = tabletIdentity
        surfaceID = eventSurfaceID
    }
}

package struct RawTabletToolButton: Equatable, Sendable {
    package let tool: RawTabletToolIdentity
    package let serial: UInt32
    package let button: UInt32
    package let state: RawPointerButtonState

    package init(
        tool toolIdentity: RawTabletToolIdentity,
        serial eventSerial: UInt32,
        button eventButton: UInt32,
        state eventState: RawPointerButtonState
    ) {
        tool = toolIdentity
        serial = eventSerial
        button = eventButton
        state = eventState
    }
}

package enum RawTabletPadEvent: Equatable, Sendable {
    case path(RawTabletPadIdentity, String)
    case buttons(RawTabletPadIdentity, UInt32)
    case done(RawTabletPadIdentity)
    case button(RawTabletPadButton)
    case enter(RawTabletPadEnter)
    case leave(RawTabletPadLeave)
    case removed(RawTabletPadIdentity)
    case groupAdded(RawTabletPadIdentity)
}

package struct RawTabletPadButton: Equatable, Sendable {
    package let pad: RawTabletPadIdentity
    package let time: UInt32
    package let button: UInt32
    package let state: RawPointerButtonState

    package init(
        pad padIdentity: RawTabletPadIdentity,
        time eventTime: UInt32,
        button eventButton: UInt32,
        state eventState: RawPointerButtonState
    ) {
        pad = padIdentity
        time = eventTime
        button = eventButton
        state = eventState
    }
}

package struct RawTabletPadEnter: Equatable, Sendable {
    package let pad: RawTabletPadIdentity
    package let serial: UInt32
    package let tablet: RawTabletIdentity
    package let surfaceID: RawObjectID?

    package init(
        pad padIdentity: RawTabletPadIdentity,
        serial eventSerial: UInt32,
        tablet tabletIdentity: RawTabletIdentity,
        surfaceID eventSurfaceID: RawObjectID?
    ) {
        pad = padIdentity
        serial = eventSerial
        tablet = tabletIdentity
        surfaceID = eventSurfaceID
    }
}

package struct RawTabletPadLeave: Equatable, Sendable {
    package let pad: RawTabletPadIdentity
    package let serial: UInt32
    package let surfaceID: RawObjectID?

    package init(
        pad padIdentity: RawTabletPadIdentity,
        serial eventSerial: UInt32,
        surfaceID eventSurfaceID: RawObjectID?
    ) {
        pad = padIdentity
        serial = eventSerial
        surfaceID = eventSurfaceID
    }
}
