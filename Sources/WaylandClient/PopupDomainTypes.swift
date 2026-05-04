import WaylandRaw

package struct LogicalOffset: Equatable, Sendable, CustomStringConvertible {
    package let x: Int32
    package let y: Int32

    package init(x offsetX: Int32, y offsetY: Int32) {
        x = offsetX
        y = offsetY
    }

    package static let zero = LogicalOffset(x: 0, y: 0)

    package var description: String {
        "\(x),\(y)"
    }
}

package struct LogicalRect: Equatable, Sendable, CustomStringConvertible {
    package let origin: LogicalOffset
    package let size: PositiveLogicalSize

    package init(origin rectOrigin: LogicalOffset, size rectSize: PositiveLogicalSize) {
        origin = rectOrigin
        size = rectSize
    }

    package init(x rectX: Int32, y rectY: Int32, width rectWidth: Int32, height rectHeight: Int32)
        throws
    {
        origin = LogicalOffset(x: rectX, y: rectY)
        size = try PositiveLogicalSize(width: rectWidth, height: rectHeight)
    }

    package var description: String {
        "\(origin) \(size)"
    }
}

package enum PopupAnchor: Equatable, Sendable {
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

package enum PopupGravity: Equatable, Sendable {
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

package struct PopupConstraintAdjustment:
    Equatable,
    Sendable,
    ExpressibleByArrayLiteral
{
    package let rawValue: UInt32

    private init(rawValue adjustmentRawValue: UInt32) {
        rawValue = adjustmentRawValue
    }

    package init(_ adjustments: [PopupConstraintAdjustment]) {
        rawValue = adjustments.reduce(0) { bits, adjustment in
            bits | adjustment.rawValue
        }
    }

    package init(arrayLiteral adjustments: PopupConstraintAdjustment...) {
        self.init(adjustments)
    }

    package func contains(_ adjustment: PopupConstraintAdjustment) -> Bool {
        rawValue & adjustment.rawValue == adjustment.rawValue
    }

    package func union(_ adjustment: PopupConstraintAdjustment) -> PopupConstraintAdjustment {
        PopupConstraintAdjustment(rawValue: rawValue | adjustment.rawValue)
    }

    package static let none = Self(rawValue: 0)
    package static let slideX = Self(rawValue: 1)
    package static let slideY = Self(rawValue: 2)
    package static let flipX = Self(rawValue: 4)
    package static let flipY = Self(rawValue: 8)
    package static let resizeX = Self(rawValue: 16)
    package static let resizeY = Self(rawValue: 32)
}

package struct PopupPositioner: Equatable, Sendable {
    package var anchorRect: LogicalRect
    package var size: PositiveLogicalSize
    package var anchor: PopupAnchor
    package var gravity: PopupGravity
    package var constraintAdjustment: PopupConstraintAdjustment
    package var offset: LogicalOffset

    package init(
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

package enum PopupGrabPolicy: Equatable, Sendable {
    case none
    case explicit(seatID: SeatID, serial: InputSerial)
}

package struct PopupConfiguration: Equatable, Sendable {
    package var positioner: PopupPositioner
    package var grab: PopupGrabPolicy

    package init(
        positioner popupPositioner: PopupPositioner,
        grab popupGrab: PopupGrabPolicy = .none
    ) {
        positioner = popupPositioner
        grab = popupGrab
    }
}

package struct PopupPlacement: Equatable, Sendable {
    package let origin: LogicalOffset
    package let size: PositiveLogicalSize

    package init(origin placementOrigin: LogicalOffset, size placementSize: PositiveLogicalSize) {
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
