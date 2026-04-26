public struct TopLevelSize: Equatable, Sendable {
    public let width: Int32
    public let height: Int32

    public static let fallback = TopLevelSize(width: 640, height: 480)

    public init(width sizeWidth: Int32, height sizeHeight: Int32) {
        width = sizeWidth
        height = sizeHeight
    }

    public func normalized(fallback: TopLevelSize = .fallback) -> Self {
        Self(
            width: width > 0 ? width : fallback.width,
            height: height > 0 ? height : fallback.height)
    }
}

public struct XDGTopLevelState: Equatable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    public static let maximized = Self(rawValue: 1)
    public static let fullscreen = Self(rawValue: 2)
    public static let resizing = Self(rawValue: 3)
    public static let activated = Self(rawValue: 4)
    public static let tiledLeft = Self(rawValue: 5)
    public static let tiledRight = Self(rawValue: 6)
    public static let tiledTop = Self(rawValue: 7)
    public static let tiledBottom = Self(rawValue: 8)
    public static let suspended = Self(rawValue: 9)
}

public struct XDGWMCapability: Equatable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue capabilityRawValue: UInt32) {
        rawValue = capabilityRawValue
    }

    public static let windowMenu = Self(rawValue: 1)
    public static let maximize = Self(rawValue: 2)
    public static let fullscreen = Self(rawValue: 3)
    public static let minimize = Self(rawValue: 4)
}

public struct SurfaceConfigure: Equatable, Sendable {
    public let serial: UInt32
    public let size: TopLevelSize
    public let states: [XDGTopLevelState]
    public let bounds: TopLevelSize?
    public let wmCapabilities: [XDGWMCapability]

    public init(
        serial configureSerial: UInt32,
        size configureSize: TopLevelSize,
        states configureStates: [XDGTopLevelState] = [],
        bounds configureBounds: TopLevelSize? = nil,
        wmCapabilities configureWMCapabilities: [XDGWMCapability] = []
    ) {
        serial = configureSerial
        size = configureSize
        states = configureStates
        bounds = configureBounds
        wmCapabilities = configureWMCapabilities
    }
}

public final class XDGConfigureState {
    private let fallbackSize: TopLevelSize
    private var pendingSize: TopLevelSize
    private var pendingStates: [XDGTopLevelState] = []
    private var pendingBounds: TopLevelSize?
    private var pendingWMCapabilities: [XDGWMCapability] = []
    private var latestConfigure: SurfaceConfigure?

    public private(set) var hasReceivedInitialConfigure = false

    public init(fallbackSize initialFallbackSize: TopLevelSize = .fallback) {
        fallbackSize = initialFallbackSize
        pendingSize = initialFallbackSize
    }

    public func handleTopLevelConfigure(
        width: Int32,
        height: Int32,
        states: [XDGTopLevelState] = []
    ) {
        pendingSize = TopLevelSize(width: width, height: height)
            .normalized(fallback: fallbackSize)
        pendingStates = states
    }

    public func handleConfigureBounds(width: Int32, height: Int32) {
        pendingBounds = TopLevelSize(width: width, height: height)
            .normalized(fallback: fallbackSize)
    }

    public func handleWMCapabilities(_ capabilities: [XDGWMCapability]) {
        pendingWMCapabilities = capabilities
    }

    @discardableResult
    public func handleSurfaceConfigure(serial: UInt32) -> SurfaceConfigure {
        let configure = SurfaceConfigure(
            serial: serial,
            size: pendingSize,
            states: pendingStates,
            bounds: pendingBounds,
            wmCapabilities: pendingWMCapabilities
        )
        latestConfigure = configure
        hasReceivedInitialConfigure = true
        return configure
    }

    public func consumeLatestConfigure() -> SurfaceConfigure? {
        defer {
            latestConfigure = nil
        }

        return latestConfigure
    }
}
