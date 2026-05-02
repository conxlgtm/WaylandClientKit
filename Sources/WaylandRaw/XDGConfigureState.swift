public struct TopLevelSize: Equatable, Sendable {
    public let width: Int32
    public let height: Int32

    public static let unspecified = TopLevelSize(width: 0, height: 0)

    public init(width sizeWidth: Int32, height sizeHeight: Int32) {
        width = sizeWidth
        height = sizeHeight
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
    public static let constrainedLeft = Self(rawValue: 10)
    public static let constrainedRight = Self(rawValue: 11)
    public static let constrainedTop = Self(rawValue: 12)
    public static let constrainedBottom = Self(rawValue: 13)
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

public struct XDGTopLevelConfigureSuggestion: Equatable, Sendable {
    public let size: TopLevelSize
    public let states: [XDGTopLevelState]
    public let bounds: TopLevelSize?
    public let wmCapabilities: [XDGWMCapability]

    public init(
        size configureSize: TopLevelSize,
        states configureStates: [XDGTopLevelState] = [],
        bounds configureBounds: TopLevelSize? = nil,
        wmCapabilities configureWMCapabilities: [XDGWMCapability] = []
    ) {
        size = configureSize
        states = configureStates
        bounds = configureBounds
        wmCapabilities = configureWMCapabilities
    }
}

public struct XDGConfigureSequence: Equatable, Sendable {
    public let serial: UInt32
    public let topLevel: XDGTopLevelConfigureSuggestion

    public init(
        serial configureSerial: UInt32,
        topLevel topLevelSuggestion: XDGTopLevelConfigureSuggestion
    ) {
        serial = configureSerial
        topLevel = topLevelSuggestion
    }
}

public final class XDGConfigureState {
    private var pendingSize: TopLevelSize
    private var pendingStates: [XDGTopLevelState] = []
    private var pendingBounds: TopLevelSize?
    private var pendingWMCapabilities: [XDGWMCapability] = []
    private var latestConfigure: XDGConfigureSequence?
    private var pendingError: RuntimeError?
    private var onSurfaceConfigure: (() -> Void)?

    public private(set) var hasReceivedInitialConfigure = false

    public init(initialSize: TopLevelSize = .unspecified) {
        pendingSize = initialSize
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    public func handleTopLevelConfigure(
        width: Int32,
        height: Int32,
        states: [XDGTopLevelState] = []
    ) {
        pendingSize = TopLevelSize(width: width, height: height)
        pendingStates = states
    }

    public func handleConfigureBounds(width: Int32, height: Int32) {
        guard width > 0, height > 0 else {
            pendingBounds = nil
            return
        }

        pendingBounds = TopLevelSize(width: width, height: height)
    }

    public func handleWMCapabilities(_ capabilities: [XDGWMCapability]) {
        pendingWMCapabilities = capabilities
    }

    package func recordError(_ error: RuntimeError) {
        if pendingError == nil {
            pendingError = error
        }
    }

    package func throwPendingErrorIfAny() throws {
        guard let error = pendingError else { return }

        pendingError = nil
        throw error
    }

    @discardableResult
    public func handleSurfaceConfigure(serial: UInt32) -> XDGConfigureSequence {
        let configure = XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: pendingSize,
                states: pendingStates,
                bounds: pendingBounds,
                wmCapabilities: pendingWMCapabilities
            )
        )
        latestConfigure = configure
        hasReceivedInitialConfigure = true
        onSurfaceConfigure?()
        return configure
    }

    public func consumeLatestConfigure() -> XDGConfigureSequence? {
        defer {
            latestConfigure = nil
        }

        return latestConfigure
    }
}
