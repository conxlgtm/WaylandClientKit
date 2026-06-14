public struct TabletID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue tabletRawValue: UInt32) {
        rawValue = tabletRawValue
    }

    public var description: String {
        "tablet-\(rawValue)"
    }
}

public struct TabletToolID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue toolRawValue: UInt32) {
        rawValue = toolRawValue
    }

    public var description: String {
        "tablet-tool-\(rawValue)"
    }
}

public struct TabletPadID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue padRawValue: UInt32) {
        rawValue = padRawValue
    }

    public var description: String {
        "tablet-pad-\(rawValue)"
    }
}

public enum TabletEvent: Equatable, Sendable {
    case tabletAdded(TabletID)
    case toolAdded(TabletToolID)
    case padAdded(TabletPadID)
    case tablet(TabletDeviceEvent)
    case tool(TabletToolEvent)
    case pad(TabletPadEvent)
}

public enum TabletDeviceEvent: Equatable, Sendable {
    case name(TabletID, String)
    case id(TabletID, vendorID: UInt32, productID: UInt32)
    case path(TabletID, String)
    case done(TabletID)
    case removed(TabletID)
    case busType(TabletID, TabletBusType)
}

public enum TabletBusType: Equatable, Sendable {
    case usb
    case bluetooth
    case virtual
    case serial
    case i2c
    case unknown(UInt32)

    public init(rawValue busTypeRawValue: UInt32) {
        switch busTypeRawValue {
        case 3:
            self = .usb
        case 5:
            self = .bluetooth
        case 6:
            self = .virtual
        case 17:
            self = .serial
        case 24:
            self = .i2c
        default:
            self = .unknown(busTypeRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .usb:
            3
        case .bluetooth:
            5
        case .virtual:
            6
        case .serial:
            17
        case .i2c:
            24
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum TabletToolEvent: Equatable, Sendable {
    case type(TabletToolID, TabletToolType)
    case hardwareSerial(TabletToolID, UInt64)
    case hardwareIDWacom(TabletToolID, UInt64)
    case capability(TabletToolID, TabletToolCapability)
    case done(TabletToolID)
    case removed(TabletToolID)
    case proximityIn(TabletToolProximityIn)
    case proximityOut(TabletToolID)
    case down(TabletToolID, serial: InputSerial)
    case up(TabletToolID)
    case motion(TabletToolID, PointerLocation)
    case pressure(TabletToolID, UInt32)
    case distance(TabletToolID, UInt32)
    case tilt(TabletToolID, x: Double, y: Double)
    case rotation(TabletToolID, degrees: Double)
    case slider(TabletToolID, position: Int32)
    case wheel(TabletToolID, degrees: Double, clicks: Int32)
    case button(TabletToolButton)
    case frame(TabletToolID, time: WaylandTimestampMilliseconds)
}

public enum TabletToolType: Equatable, Sendable {
    case pen
    case eraser
    case brush
    case pencil
    case airbrush
    case finger
    case mouse
    case lens
    case unknown(UInt32)

    public init(rawValue typeRawValue: UInt32) {
        switch typeRawValue {
        case 0x140:
            self = .pen
        case 0x141:
            self = .eraser
        case 0x142:
            self = .brush
        case 0x143:
            self = .pencil
        case 0x144:
            self = .airbrush
        case 0x145:
            self = .finger
        case 0x146:
            self = .mouse
        case 0x147:
            self = .lens
        default:
            self = .unknown(typeRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .pen:
            0x140
        case .eraser:
            0x141
        case .brush:
            0x142
        case .pencil:
            0x143
        case .airbrush:
            0x144
        case .finger:
            0x145
        case .mouse:
            0x146
        case .lens:
            0x147
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public enum TabletToolCapability: Equatable, Hashable, Sendable {
    case tilt
    case pressure
    case distance
    case rotation
    case slider
    case wheel
    case unknown(UInt32)

    public init(rawValue capabilityRawValue: UInt32) {
        switch capabilityRawValue {
        case 1:
            self = .tilt
        case 2:
            self = .pressure
        case 3:
            self = .distance
        case 4:
            self = .rotation
        case 5:
            self = .slider
        case 6:
            self = .wheel
        default:
            self = .unknown(capabilityRawValue)
        }
    }

    public var rawValue: UInt32 {
        switch self {
        case .tilt:
            1
        case .pressure:
            2
        case .distance:
            3
        case .rotation:
            4
        case .slider:
            5
        case .wheel:
            6
        case .unknown(let rawValue):
            rawValue
        }
    }
}

public struct TabletToolProximityIn: Equatable, Sendable {
    public let tool: TabletToolID
    public let serial: InputSerial
    public let tablet: TabletID

    public init(tool toolID: TabletToolID, serial eventSerial: InputSerial, tablet tabletID: TabletID) {
        tool = toolID
        serial = eventSerial
        tablet = tabletID
    }
}

public struct TabletToolButton: Equatable, Sendable {
    public let tool: TabletToolID
    public let serial: InputSerial
    public let button: PointerButtonCode
    public let state: ButtonState

    public init(
        tool toolID: TabletToolID,
        serial eventSerial: InputSerial,
        button buttonCode: PointerButtonCode,
        state buttonState: ButtonState
    ) {
        tool = toolID
        serial = eventSerial
        button = buttonCode
        state = buttonState
    }
}

public enum TabletPadEvent: Equatable, Sendable {
    case path(TabletPadID, String)
    case buttons(TabletPadID, UInt32)
    case done(TabletPadID)
    case button(TabletPadButton)
    case enter(TabletPadEnter)
    case leave(TabletPadLeave)
    case removed(TabletPadID)
    case groupAdded(TabletPadID)
}

public struct TabletPadButton: Equatable, Sendable {
    public let pad: TabletPadID
    public let time: WaylandTimestampMilliseconds
    public let button: PointerButtonCode
    public let state: ButtonState

    public init(
        pad padID: TabletPadID,
        time eventTime: WaylandTimestampMilliseconds,
        button buttonCode: PointerButtonCode,
        state buttonState: ButtonState
    ) {
        pad = padID
        time = eventTime
        button = buttonCode
        state = buttonState
    }
}

public struct TabletPadEnter: Equatable, Sendable {
    public let pad: TabletPadID
    public let serial: InputSerial
    public let tablet: TabletID

    public init(pad padID: TabletPadID, serial eventSerial: InputSerial, tablet tabletID: TabletID) {
        pad = padID
        serial = eventSerial
        tablet = tabletID
    }
}

public struct TabletPadLeave: Equatable, Sendable {
    public let pad: TabletPadID
    public let serial: InputSerial

    public init(pad padID: TabletPadID, serial eventSerial: InputSerial) {
        pad = padID
        serial = eventSerial
    }
}
