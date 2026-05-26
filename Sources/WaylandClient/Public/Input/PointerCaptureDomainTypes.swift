public enum PointerCaptureFeature: Equatable, Sendable, CustomStringConvertible {
    case relativePointer
    case pointerConstraints

    public var description: String {
        switch self {
        case .relativePointer:
            "relative pointer"
        case .pointerConstraints:
            "pointer constraints"
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
    case displayClosed
    case emptyRegion
    case alreadyConstrained(seatID: SeatID)
    case invalidCursorHint(PointerLocation)
    case unknownRelativePointerSubscription(RelativePointerSubscriptionID)
    case unknownPointerConstraint(PointerConstraintID)
    case foreignRelativePointerSubscription(RelativePointerSubscriptionID)
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
        case .displayClosed:
            "display is closed"
        case .emptyRegion:
            "pointer constraint region must contain at least one rectangle"
        case .alreadyConstrained(let seatID):
            "seat \(seatID) already has a pointer constraint for this surface"
        case .invalidCursorHint(let location):
            "pointer constraint cursor hint \(location) cannot be represented as Wayland fixed point"
        case .unknownRelativePointerSubscription(let subscriptionID):
            "relative pointer subscription \(subscriptionID) is not registered"
        case .unknownPointerConstraint(let constraintID):
            "pointer constraint \(constraintID) is not registered"
        case .foreignRelativePointerSubscription(let subscriptionID):
            "relative pointer subscription \(subscriptionID) belongs to a different display"
        case .foreignPointerConstraint(let constraintID):
            "pointer constraint \(constraintID) belongs to a different display"
        }
    }
}

public struct RelativePointerSubscriptionID: Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    public let rawValue: UInt64

    public init(rawValue subscriptionRawValue: UInt64) {
        rawValue = subscriptionRawValue
    }

    public var description: String {
        "relative-pointer-\(rawValue)"
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
