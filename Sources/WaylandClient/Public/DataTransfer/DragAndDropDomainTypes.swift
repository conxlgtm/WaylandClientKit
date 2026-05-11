import WaylandRaw

public struct DragActionSet: OptionSet, Sendable, Hashable, CustomStringConvertible {
    public let rawValue: UInt32

    public static let copy = Self(rawValue: 1 << 0)
    public static let move = Self(rawValue: 1 << 1)
    public static let ask = Self(rawValue: 1 << 2)

    package static let knownProtocolActions: Self = [.copy, .move, .ask]

    public init(rawValue actionRawValue: UInt32) {
        rawValue = actionRawValue
    }

    package init(rawDataDeviceDNDAction action: RawDataDeviceDNDAction) {
        self.init(rawValue: action.rawValue)
    }

    package var rawDataDeviceDNDAction: RawDataDeviceDNDAction {
        RawDataDeviceDNDAction(rawValue: rawValue)
    }

    package var unknownProtocolBits: UInt32 {
        rawValue & ~Self.knownProtocolActions.rawValue
    }

    package var containsOnlyKnownProtocolActions: Bool {
        unknownProtocolBits == 0
    }

    public var description: String {
        var names: [String] = []
        if contains(.copy) {
            names.append("copy")
        }
        if contains(.move) {
            names.append("move")
        }
        if contains(.ask) {
            names.append("ask")
        }
        let unknownBits = unknownProtocolBits
        if unknownBits != 0 {
            names.append("unknown(\(unknownBits))")
        }
        return names.isEmpty ? "none" : names.joined(separator: ",")
    }
}

public enum DragAction: Equatable, Sendable, CustomStringConvertible {
    case none
    case copy
    case move
    case ask
    case unknown(rawValue: UInt32)

    package init(rawDataDeviceDNDAction action: RawDataDeviceDNDAction) {
        switch action.rawValue {
        case RawDataDeviceDNDAction.none.rawValue:
            self = .none
        case RawDataDeviceDNDAction.copy.rawValue:
            self = .copy
        case RawDataDeviceDNDAction.move.rawValue:
            self = .move
        case RawDataDeviceDNDAction.ask.rawValue:
            self = .ask
        default:
            self = .unknown(rawValue: action.rawValue)
        }
    }

    package var rawDataDeviceDNDAction: RawDataDeviceDNDAction {
        switch self {
        case .none:
            .none
        case .copy:
            .copy
        case .move:
            .move
        case .ask:
            .ask
        case .unknown(let rawValue):
            RawDataDeviceDNDAction(rawValue: rawValue)
        }
    }

    package var actionSetMember: DragActionSet {
        switch self {
        case .none:
            []
        case .copy:
            .copy
        case .move:
            .move
        case .ask:
            .ask
        case .unknown(let rawValue):
            DragActionSet(rawValue: rawValue)
        }
    }

    package var isKnownProtocolAction: Bool {
        switch self {
        case .none, .copy, .move, .ask:
            true
        case .unknown:
            false
        }
    }

    package var isFinalTransferAction: Bool {
        switch self {
        case .copy, .move:
            true
        case .none, .ask, .unknown:
            false
        }
    }

    public var description: String {
        switch self {
        case .none:
            "none"
        case .copy:
            "copy"
        case .move:
            "move"
        case .ask:
            "ask"
        case .unknown(let rawValue):
            "unknown(\(rawValue))"
        }
    }
}

public struct DragOfferIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ offerID: DataOfferID) {
        rawValue = offerID.rawValue
    }

    public var description: String {
        "drag-offer-\(rawValue)"
    }
}

public struct DragLocation: Equatable, Sendable {
    public let x: Double
    public let y: Double

    package init(x positionX: Double, y positionY: Double) {
        x = positionX
        y = positionY
    }
}

public struct DragEnterEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: DragOfferIdentity
    public let serial: InputSerial
    public let location: DragLocation
    public let target: InputEventTarget

    package init(
        seatID eventSeatID: SeatID,
        offerID eventOfferID: DataOfferID,
        serial eventSerial: InputSerial,
        location eventLocation: DragLocation,
        target eventTarget: InputEventTarget
    ) {
        seatID = eventSeatID
        offer = DragOfferIdentity(eventOfferID)
        serial = eventSerial
        location = eventLocation
        target = eventTarget
    }
}

public struct DragMotionEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: DragOfferIdentity
    public let time: WaylandTimestampMilliseconds
    public let location: DragLocation

    package init(
        seatID eventSeatID: SeatID,
        offerID eventOfferID: DataOfferID,
        time eventTime: WaylandTimestampMilliseconds,
        location eventLocation: DragLocation
    ) {
        seatID = eventSeatID
        offer = DragOfferIdentity(eventOfferID)
        time = eventTime
        location = eventLocation
    }
}

public struct DragLeaveEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: DragOfferIdentity

    package init(seatID eventSeatID: SeatID, offerID eventOfferID: DataOfferID) {
        seatID = eventSeatID
        offer = DragOfferIdentity(eventOfferID)
    }
}

public struct DragDropEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: DragOfferIdentity

    package init(seatID eventSeatID: SeatID, offerID eventOfferID: DataOfferID) {
        seatID = eventSeatID
        offer = DragOfferIdentity(eventOfferID)
    }
}

public struct DragOfferChangedEvent: Equatable, Sendable {
    public let seatID: SeatID
    public let offer: DragOfferIdentity

    package init(seatID eventSeatID: SeatID, offerID eventOfferID: DataOfferID) {
        seatID = eventSeatID
        offer = DragOfferIdentity(eventOfferID)
    }
}
