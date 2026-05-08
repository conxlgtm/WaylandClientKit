import WaylandRaw

public struct LogicalOffset: Equatable, Sendable, CustomStringConvertible {
    public let x: Int32
    public let y: Int32

    public init(x offsetX: Int32, y offsetY: Int32) {
        x = offsetX
        y = offsetY
    }

    public static let zero = LogicalOffset(x: 0, y: 0)

    public var description: String {
        "\(x),\(y)"
    }
}

public struct LogicalRect: Equatable, Sendable, CustomStringConvertible {
    public let origin: LogicalOffset
    public let size: PositiveLogicalSize

    public init(origin rectOrigin: LogicalOffset, size rectSize: PositiveLogicalSize) {
        origin = rectOrigin
        size = rectSize
    }

    public init(x rectX: Int32, y rectY: Int32, width rectWidth: Int32, height rectHeight: Int32)
        throws
    {
        origin = LogicalOffset(x: rectX, y: rectY)
        size = try PositiveLogicalSize(width: rectWidth, height: rectHeight)
    }

    public var description: String {
        "\(origin) \(size)"
    }
}

public enum PopupAnchor: Equatable, Sendable {
    case none
    case top
    case bottom
    case left
    case right
    case topLeft
    case bottomLeft
    case topRight
    case bottomRight
}

public enum PopupGravity: Equatable, Sendable {
    case none
    case top
    case bottom
    case left
    case right
    case topLeft
    case bottomLeft
    case topRight
    case bottomRight
}

public struct PopupConstraintAdjustment:
    Equatable,
    Sendable,
    ExpressibleByArrayLiteral
{
    package let rawValue: UInt32

    private init(rawValue adjustmentRawValue: UInt32) {
        rawValue = adjustmentRawValue
    }

    public init(_ adjustments: [PopupConstraintAdjustment]) {
        rawValue = adjustments.reduce(0) { bits, adjustment in
            bits | adjustment.rawValue
        }
    }

    public init(arrayLiteral adjustments: PopupConstraintAdjustment...) {
        self.init(adjustments)
    }

    public func contains(_ adjustment: PopupConstraintAdjustment) -> Bool {
        rawValue & adjustment.rawValue == adjustment.rawValue
    }

    public func union(_ adjustment: PopupConstraintAdjustment) -> PopupConstraintAdjustment {
        PopupConstraintAdjustment(rawValue: rawValue | adjustment.rawValue)
    }

    public static let none = Self(rawValue: 0)
    public static let slideX = Self(rawValue: 1)
    public static let slideY = Self(rawValue: 2)
    public static let flipX = Self(rawValue: 4)
    public static let flipY = Self(rawValue: 8)
    public static let resizeX = Self(rawValue: 16)
    public static let resizeY = Self(rawValue: 32)
}

public struct PopupPositioner: Equatable, Sendable {
    public var anchorRect: LogicalRect
    public var size: PositiveLogicalSize
    public var anchor: PopupAnchor
    public var gravity: PopupGravity
    public var constraintAdjustment: PopupConstraintAdjustment
    public var offset: LogicalOffset

    public init(
        anchorRect popupAnchorRect: LogicalRect,
        size popupSize: PositiveLogicalSize,
        anchor popupAnchor: PopupAnchor = .none,
        gravity popupGravity: PopupGravity = .none,
        constraintAdjustment popupConstraintAdjustment: PopupConstraintAdjustment = .none,
        offset popupOffset: LogicalOffset = .zero
    ) {
        anchorRect = popupAnchorRect
        size = popupSize
        anchor = popupAnchor
        gravity = popupGravity
        constraintAdjustment = popupConstraintAdjustment
        offset = popupOffset
    }
}

public enum PopupGrabPolicy: Equatable, Sendable {
    case none
    case explicit(seatID: SeatID, serial: InputSerial)
}

public struct PopupConfiguration: Equatable, Sendable {
    public var positioner: PopupPositioner
    public var grab: PopupGrabPolicy

    public init(
        positioner popupPositioner: PopupPositioner,
        grab popupGrab: PopupGrabPolicy = .none
    ) {
        positioner = popupPositioner
        grab = popupGrab
    }
}

public struct PopupPlacement: Equatable, Sendable {
    public let origin: LogicalOffset
    public let size: PositiveLogicalSize

    public init(origin placementOrigin: LogicalOffset, size placementSize: PositiveLogicalSize) {
        origin = placementOrigin
        size = placementSize
    }
}

extension PopupAnchor {
    package var rawXDGAnchor: RawXDGPositionerAnchor {
        switch self {
        case .none:
            .none
        case .top:
            .top
        case .bottom:
            .bottom
        case .left:
            .left
        case .right:
            .right
        case .topLeft:
            .topLeft
        case .bottomLeft:
            .bottomLeft
        case .topRight:
            .topRight
        case .bottomRight:
            .bottomRight
        }
    }
}

extension PopupGravity {
    package var rawXDGGravity: RawXDGPositionerGravity {
        switch self {
        case .none:
            .none
        case .top:
            .top
        case .bottom:
            .bottom
        case .left:
            .left
        case .right:
            .right
        case .topLeft:
            .topLeft
        case .bottomLeft:
            .bottomLeft
        case .topRight:
            .topRight
        case .bottomRight:
            .bottomRight
        }
    }
}

extension PopupConstraintAdjustment {
    package var rawXDGConstraintAdjustment: RawXDGPositionerConstraintAdjustment {
        RawXDGPositionerConstraintAdjustment(rawValue: rawValue)
    }
}

extension PopupPositioner {
    package func apply(to positioner: RawXDGPositioner) {
        positioner.setSize(
            width: size.width.rawValue,
            height: size.height.rawValue
        )
        positioner.setAnchorRect(
            x: anchorRect.origin.x,
            y: anchorRect.origin.y,
            width: anchorRect.size.width.rawValue,
            height: anchorRect.size.height.rawValue
        )
        positioner.setAnchor(anchor.rawXDGAnchor)
        positioner.setGravity(gravity.rawXDGGravity)
        positioner.setConstraintAdjustment(
            constraintAdjustment.rawXDGConstraintAdjustment
        )
        positioner.setOffset(x: offset.x, y: offset.y)
    }
}
