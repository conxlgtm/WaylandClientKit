public enum PointerCaptureFeature: Equatable, Sendable, CustomStringConvertible {
    case relativePointer
    case pointerConstraints
    case pointerGestures

    public var description: String {
        switch self {
        case .relativePointer:
            "relative pointer"
        case .pointerConstraints:
            "pointer constraints"
        case .pointerGestures:
            "pointer gestures"
        }
    }
}

public enum PointerConstraintLifetime: Equatable, Sendable {
    case oneShot
    case persistent
}

public struct PointerConstraintRegion: Equatable, Sendable {
    public let rectangles: [LogicalRect]

    public init(_ constraintRectangles: [LogicalRect]) throws {
        guard !constraintRectangles.isEmpty else {
            throw PointerCaptureError.emptyRegion
        }

        rectangles = constraintRectangles
    }

    public init(_ rectangle: LogicalRect) {
        rectangles = [rectangle]
    }
}

public enum PointerCaptureError: Error, Equatable, Sendable, CustomStringConvertible {
    case unavailable(PointerCaptureFeature)
    case foreignWindow(WindowID)
    case unknownWindow(WindowID)
    case closedWindow(WindowID)
    case unknownSeat(SeatID)
    case pointerUnavailable(SeatID)
    case displayClosed
    case emptyRegion
    case relativePointerAlreadySubscribed(seatID: SeatID)
    case alreadyConstrained(seatID: SeatID)
    case pointerGesturesAlreadySubscribed(seatID: SeatID)
    case invalidCursorHint(PointerLocation)
    case unknownRelativePointerSubscription(RelativePointerSubscriptionID)
    case unknownPointerGestureSubscription(PointerGestureSubscriptionID)
    case unknownPointerConstraint(PointerConstraintID)
    case foreignRelativePointerSubscription(RelativePointerSubscriptionID)
    case foreignPointerGestureSubscription(PointerGestureSubscriptionID)
    case foreignPointerConstraint(PointerConstraintID)

    public var description: String {
        switch self {
        case .unavailable(let feature):
            "\(feature) protocol is not available on this display"
        case .foreignWindow(let windowID):
            "window \(windowID) belongs to a different display"
        case .unknownWindow(let windowID):
            "window \(windowID) is not registered on this display"
        case .closedWindow(let windowID):
            "window \(windowID) is closed"
        case .unknownSeat(let seatID):
            "seat \(seatID) is not registered on this display"
        case .pointerUnavailable(let seatID):
            "seat \(seatID) does not have an active pointer"
        case .displayClosed:
            "display is closed"
        case .emptyRegion:
            "pointer constraint region must contain at least one rectangle"
        case .relativePointerAlreadySubscribed(let seatID):
            "seat \(seatID) already has a relative pointer subscription"
        case .alreadyConstrained(let seatID):
            "seat \(seatID) already has a pointer constraint for this surface"
        case .pointerGesturesAlreadySubscribed(let seatID):
            "seat \(seatID) already has a pointer gesture subscription"
        case .invalidCursorHint(let location):
            "pointer constraint cursor hint \(location) cannot be represented "
                + "as Wayland fixed point"
        case .unknownRelativePointerSubscription(let subscriptionID):
            "relative pointer subscription \(subscriptionID) is not registered"
        case .unknownPointerGestureSubscription(let subscriptionID):
            "pointer gesture subscription \(subscriptionID) is not registered"
        case .unknownPointerConstraint(let constraintID):
            "pointer constraint \(constraintID) is not registered"
        case .foreignRelativePointerSubscription(let subscriptionID):
            "relative pointer subscription \(subscriptionID) belongs to a different display"
        case .foreignPointerGestureSubscription(let subscriptionID):
            "pointer gesture subscription \(subscriptionID) belongs to a different display"
        case .foreignPointerConstraint(let constraintID):
            "pointer constraint \(constraintID) belongs to a different display"
        }
    }
}

public struct RelativePointerSubscription: Hashable, Sendable {
    public let id: RelativePointerSubscriptionID
    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<RelativePointerSubscriptionID>

    package init(
        id subscriptionID: RelativePointerSubscriptionID,
        display owningDisplay: WaylandDisplay
    ) {
        id = subscriptionID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: subscriptionID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }

    public func destroy() async throws {
        try await display.destroyRelativePointerSubscription(self)
    }
}

public struct PointerGestureSubscription: Hashable, Sendable, Identifiable {
    public let id: PointerGestureSubscriptionID
    public let seatID: SeatID
    public let version: UInt32
    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<PointerGestureSubscriptionID>

    package init(
        id subscriptionID: PointerGestureSubscriptionID,
        seatID subscriptionSeatID: SeatID,
        version protocolVersion: UInt32,
        display owningDisplay: WaylandDisplay
    ) {
        id = subscriptionID
        seatID = subscriptionSeatID
        version = protocolVersion
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: subscriptionID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }

    public func destroy() async throws {
        try await display.destroyPointerGestureSubscription(self)
    }
}

public struct PointerConstraint: Hashable, Sendable {
    public let id: PointerConstraintID
    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<PointerConstraintID>

    package init(id constraintID: PointerConstraintID, display owningDisplay: WaylandDisplay) {
        id = constraintID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: constraintID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }

    public func destroy() async throws {
        try await display.destroyPointerConstraint(self)
    }
}
