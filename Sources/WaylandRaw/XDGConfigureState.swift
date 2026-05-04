package struct TopLevelSize: Equatable, Sendable {
    package let width: Int32
    package let height: Int32

    package static let unspecified = TopLevelSize(width: 0, height: 0)

    package init(width sizeWidth: Int32, height sizeHeight: Int32) {
        width = sizeWidth
        height = sizeHeight
    }
}

package struct XDGTopLevelState: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package init(rawValue stateRawValue: UInt32) {
        rawValue = stateRawValue
    }

    package static let maximized = Self(rawValue: 1)
    package static let fullscreen = Self(rawValue: 2)
    package static let resizing = Self(rawValue: 3)
    package static let activated = Self(rawValue: 4)
    package static let tiledLeft = Self(rawValue: 5)
    package static let tiledRight = Self(rawValue: 6)
    package static let tiledTop = Self(rawValue: 7)
    package static let tiledBottom = Self(rawValue: 8)
    package static let suspended = Self(rawValue: 9)
    package static let constrainedLeft = Self(rawValue: 10)
    package static let constrainedRight = Self(rawValue: 11)
    package static let constrainedTop = Self(rawValue: 12)
    package static let constrainedBottom = Self(rawValue: 13)
}

package struct XDGWMCapability: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package init(rawValue capabilityRawValue: UInt32) {
        rawValue = capabilityRawValue
    }

    package static let windowMenu = Self(rawValue: 1)
    package static let maximize = Self(rawValue: 2)
    package static let fullscreen = Self(rawValue: 3)
    package static let minimize = Self(rawValue: 4)
}

package struct XDGTopLevelConfigureSuggestion: Equatable, Sendable {
    package let size: TopLevelSize
    package let states: [XDGTopLevelState]
    package let bounds: TopLevelSize?
    package let wmCapabilities: [XDGWMCapability]

    package init(
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

package struct XDGConfigureSequence: Equatable, Sendable {
    package let serial: UInt32
    package let topLevel: XDGTopLevelConfigureSuggestion
    package let decorationMode: RawDecorationMode?

    package init(
        serial configureSerial: UInt32,
        topLevel topLevelSuggestion: XDGTopLevelConfigureSuggestion,
        decorationMode configureDecorationMode: RawDecorationMode? = nil
    ) {
        serial = configureSerial
        topLevel = topLevelSuggestion
        decorationMode = configureDecorationMode
    }
}

package final class XDGConfigureState {
    private var pendingSize: TopLevelSize
    private var pendingStates: [XDGTopLevelState] = []
    private var pendingBounds: TopLevelSize?
    private var pendingWMCapabilities: [XDGWMCapability] = []
    private var pendingDecorationMode: RawDecorationMode?
    private var latestConfigure: XDGConfigureSequence?
    private var pendingError: RuntimeError?
    private var onSurfaceConfigure: (() -> Void)?

    package private(set) var hasReceivedInitialConfigure = false

    package init(initialSize: TopLevelSize = .unspecified) {
        pendingSize = initialSize
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    package func handleTopLevelConfigure(
        width: Int32,
        height: Int32,
        states: [XDGTopLevelState] = []
    ) {
        pendingSize = TopLevelSize(width: width, height: height)
        pendingStates = states
    }

    package func handleConfigureBounds(width: Int32, height: Int32) {
        guard width > 0, height > 0 else {
            pendingBounds = nil
            return
        }

        pendingBounds = TopLevelSize(width: width, height: height)
    }

    package func handleWMCapabilities(_ capabilities: [XDGWMCapability]) {
        pendingWMCapabilities = capabilities
    }

    package func handleDecorationConfigure(mode: RawDecorationMode) {
        pendingDecorationMode = mode
    }

    package func handleDecorationConfigure(rawMode: UInt32) {
        do {
            pendingDecorationMode = try RawDecorationMode(validating: rawMode)
        } catch {
            recordError(error)
        }
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
    package func handleSurfaceConfigure(serial: UInt32) -> XDGConfigureSequence {
        let decorationMode = pendingDecorationMode ?? latestConfigure?.decorationMode
        let configure = XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: pendingSize,
                states: pendingStates,
                bounds: pendingBounds,
                wmCapabilities: pendingWMCapabilities
            ),
            decorationMode: decorationMode
        )
        pendingDecorationMode = nil
        latestConfigure = configure
        hasReceivedInitialConfigure = true
        onSurfaceConfigure?()
        return configure
    }

    package func consumeLatestConfigure() -> XDGConfigureSequence? {
        defer {
            latestConfigure = nil
        }

        return latestConfigure
    }
}

extension XDGConfigureState: XDGSurfaceConfigureHandling {
    package func handleXDGSurfaceConfigure(serial: UInt32) {
        handleSurfaceConfigure(serial: serial)
    }
}
