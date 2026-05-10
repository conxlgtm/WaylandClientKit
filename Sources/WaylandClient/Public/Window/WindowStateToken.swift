import WaylandRaw

public enum WindowEdge: Equatable, Hashable, Sendable {
    case left
    case right
    case top
    case bottom
}

public enum WindowResizeEdge: Equatable, Hashable, Sendable {
    case top
    case bottom
    case left
    case topLeft
    case bottomLeft
    case right
    case topRight
    case bottomRight
}

public enum WindowStateToken: Equatable, Hashable, Sendable {
    case maximized
    case fullscreen
    case resizing
    case activated
    case tiled(WindowEdge)
    case suspended
    case constrained(WindowEdge)
    case unknown(UInt32)

    private static let knownStates: [UInt32: Self] = [
        XDGTopLevelState.maximized.rawValue: .maximized,
        XDGTopLevelState.fullscreen.rawValue: .fullscreen,
        XDGTopLevelState.resizing.rawValue: .resizing,
        XDGTopLevelState.activated.rawValue: .activated,
        XDGTopLevelState.tiledLeft.rawValue: .tiled(.left),
        XDGTopLevelState.tiledRight.rawValue: .tiled(.right),
        XDGTopLevelState.tiledTop.rawValue: .tiled(.top),
        XDGTopLevelState.tiledBottom.rawValue: .tiled(.bottom),
        XDGTopLevelState.suspended.rawValue: .suspended,
        XDGTopLevelState.constrainedLeft.rawValue: .constrained(.left),
        XDGTopLevelState.constrainedRight.rawValue: .constrained(.right),
        XDGTopLevelState.constrainedTop.rawValue: .constrained(.top),
        XDGTopLevelState.constrainedBottom.rawValue: .constrained(.bottom),
    ]

    package init(_ rawState: XDGTopLevelState) {
        self = Self.knownStates[rawState.rawValue] ?? .unknown(rawState.rawValue)
    }

    public var rawValue: UInt32 {
        switch self {
        case .maximized:
            XDGTopLevelState.maximized.rawValue
        case .fullscreen:
            XDGTopLevelState.fullscreen.rawValue
        case .resizing:
            XDGTopLevelState.resizing.rawValue
        case .activated:
            XDGTopLevelState.activated.rawValue
        case .tiled(let edge):
            Self.tiledRawValue(edge)
        case .suspended:
            XDGTopLevelState.suspended.rawValue
        case .constrained(let edge):
            Self.constrainedRawValue(edge)
        case .unknown(let rawValue):
            rawValue
        }
    }

    private static func tiledRawValue(_ edge: WindowEdge) -> UInt32 {
        switch edge {
        case .left:
            XDGTopLevelState.tiledLeft.rawValue
        case .right:
            XDGTopLevelState.tiledRight.rawValue
        case .top:
            XDGTopLevelState.tiledTop.rawValue
        case .bottom:
            XDGTopLevelState.tiledBottom.rawValue
        }
    }

    private static func constrainedRawValue(_ edge: WindowEdge) -> UInt32 {
        switch edge {
        case .left:
            XDGTopLevelState.constrainedLeft.rawValue
        case .right:
            XDGTopLevelState.constrainedRight.rawValue
        case .top:
            XDGTopLevelState.constrainedTop.rawValue
        case .bottom:
            XDGTopLevelState.constrainedBottom.rawValue
        }
    }
}

extension WindowResizeEdge {
    package var rawXDGResizeEdge: RawXDGTopLevelResizeEdge {
        switch self {
        case .top:
            .top
        case .bottom:
            .bottom
        case .left:
            .left
        case .topLeft:
            .topLeft
        case .bottomLeft:
            .bottomLeft
        case .right:
            .right
        case .topRight:
            .topRight
        case .bottomRight:
            .bottomRight
        }
    }
}

public enum WindowManagerCapability: Equatable, Hashable, Sendable {
    case windowMenu
    case maximize
    case fullscreen
    case minimize
    case unknown(UInt32)

    private static let knownCapabilities: [UInt32: Self] = [
        XDGWMCapability.windowMenu.rawValue: .windowMenu,
        XDGWMCapability.maximize.rawValue: .maximize,
        XDGWMCapability.fullscreen.rawValue: .fullscreen,
        XDGWMCapability.minimize.rawValue: .minimize,
    ]

    package init(_ rawCapability: XDGWMCapability) {
        self = Self.knownCapabilities[rawCapability.rawValue] ?? .unknown(rawCapability.rawValue)
    }

    public var rawValue: UInt32 {
        switch self {
        case .windowMenu:
            XDGWMCapability.windowMenu.rawValue
        case .maximize:
            XDGWMCapability.maximize.rawValue
        case .fullscreen:
            XDGWMCapability.fullscreen.rawValue
        case .minimize:
            XDGWMCapability.minimize.rawValue
        case .unknown(let rawValue):
            rawValue
        }
    }
}
