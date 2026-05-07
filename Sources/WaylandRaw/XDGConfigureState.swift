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

package enum XDGDecorationConfigure: Equatable, Sendable {
    case unchanged
    case changed(RawDecorationMode)

    package init(mode: RawDecorationMode?) {
        if let mode {
            self = .changed(mode)
        } else {
            self = .unchanged
        }
    }

    package var mode: RawDecorationMode? {
        guard case .changed(let mode) = self else {
            return nil
        }

        return mode
    }

    package func replacingUnchanged(with fallback: XDGDecorationConfigure)
        -> XDGDecorationConfigure
    {
        switch self {
        case .changed:
            self
        case .unchanged:
            fallback
        }
    }
}

package struct XDGConfigureSequence: Equatable, Sendable {
    package let serial: UInt32
    package let topLevel: XDGTopLevelConfigureSuggestion
    package let decoration: XDGDecorationConfigure

    package init(
        serial configureSerial: UInt32,
        topLevel topLevelSuggestion: XDGTopLevelConfigureSuggestion,
        decorationMode configureDecorationMode: RawDecorationMode? = nil
    ) {
        serial = configureSerial
        topLevel = topLevelSuggestion
        decoration = XDGDecorationConfigure(mode: configureDecorationMode)
    }

    package var decorationMode: RawDecorationMode? {
        decoration.mode
    }
}

private struct PendingTopLevelConfigureParts {
    var size: TopLevelSize
    var states: [XDGTopLevelState] = []
    var bounds: TopLevelSize?
    var wmCapabilities: [XDGWMCapability] = []
    var decoration = XDGDecorationConfigure.unchanged
}

private struct XDGConfigureCollection {
    var parts: PendingTopLevelConfigureParts
    var carriedDecoration = XDGDecorationConfigure.unchanged
}

private enum XDGConfigureRecoverablePhase {
    case collectingInitial(XDGConfigureCollection)
    case collecting(XDGConfigureCollection)
    case ready(XDGConfigureSequence, XDGConfigureCollection)

    var collection: XDGConfigureCollection {
        switch self {
        case .collectingInitial(let collection),
            .collecting(let collection),
            .ready(_, let collection):
            collection
        }
    }

    var hasReceivedInitialConfigure: Bool {
        switch self {
        case .collectingInitial:
            false
        case .collecting, .ready:
            true
        }
    }
}

private enum XDGConfigurePhase {
    case collectingInitial(XDGConfigureCollection)
    case collecting(XDGConfigureCollection)
    case ready(XDGConfigureSequence, XDGConfigureCollection)
    case failed(RuntimeError, recovery: XDGConfigureRecoverablePhase)
}

package final class XDGConfigureState {
    private var phase: XDGConfigurePhase
    private var onSurfaceConfigure: (() -> Void)?

    package var hasReceivedInitialConfigure: Bool {
        recoverablePhase.hasReceivedInitialConfigure
    }

    package init(initialSize: TopLevelSize = .unspecified) {
        phase = .collectingInitial(
            XDGConfigureCollection(
                parts: PendingTopLevelConfigureParts(size: initialSize)
            )
        )
    }

    package func setSurfaceConfigureHandler(_ handler: @escaping () -> Void) {
        onSurfaceConfigure = handler
    }

    package func handleTopLevelConfigure(
        width: Int32,
        height: Int32,
        states: [XDGTopLevelState] = []
    ) {
        updateCollection { collection in
            collection.parts.size = TopLevelSize(width: width, height: height)
            collection.parts.states = states
        }
    }

    package func handleConfigureBounds(width: Int32, height: Int32) {
        if width == 0, height == 0 {
            updateCollection { collection in
                collection.parts.bounds = nil
            }
            return
        }
        guard width > 0, height > 0 else {
            recordError(.invalidConfigureBounds(width: width, height: height))
            return
        }

        updateCollection { collection in
            collection.parts.bounds = TopLevelSize(width: width, height: height)
        }
    }

    package func handleWMCapabilities(_ capabilities: [XDGWMCapability]) {
        updateCollection { collection in
            collection.parts.wmCapabilities = capabilities
        }
    }

    package func handleDecorationConfigure(mode: RawDecorationMode) {
        updateCollection { collection in
            collection.parts.decoration = .changed(mode)
        }
    }

    package func handleDecorationConfigure(rawMode: UInt32) {
        do {
            handleDecorationConfigure(mode: try RawDecorationMode(validating: rawMode))
        } catch {
            recordError(error)
        }
    }

    package func recordError(_ error: RuntimeError) {
        guard case .failed = phase else {
            phase = .failed(error, recovery: recoverablePhase)
            return
        }
    }

    package func throwPendingErrorIfAny() throws {
        guard case .failed(let error, let recovery) = phase else { return }

        apply(recovery)
        throw error
    }

    @discardableResult
    package func handleSurfaceConfigure(serial: UInt32) -> XDGConfigureSequence {
        var collection = recoverablePhase.collection
        let decoration = collection.parts.decoration.replacingUnchanged(
            with: collection.carriedDecoration
        )
        let configure = XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: collection.parts.size,
                states: collection.parts.states,
                bounds: collection.parts.bounds,
                wmCapabilities: collection.parts.wmCapabilities
            ),
            decorationMode: decoration.mode
        )
        collection.parts.decoration = .unchanged
        collection.carriedDecoration = decoration
        replaceRecoverablePhase(.ready(configure, collection))
        onSurfaceConfigure?()
        return configure
    }

    package func consumeLatestConfigure() -> XDGConfigureSequence? {
        guard case .ready(let sequence, var collection) = recoverablePhase else {
            return nil
        }

        collection.carriedDecoration = .unchanged
        replaceRecoverablePhase(.collecting(collection))
        return sequence
    }

    private var recoverablePhase: XDGConfigureRecoverablePhase {
        switch phase {
        case .collectingInitial(let collection):
            .collectingInitial(collection)
        case .collecting(let collection):
            .collecting(collection)
        case .ready(let sequence, let collection):
            .ready(sequence, collection)
        case .failed(_, let recovery):
            recovery
        }
    }

    private func updateCollection(_ update: (inout XDGConfigureCollection) -> Void) {
        switch recoverablePhase {
        case .collectingInitial(var collection):
            update(&collection)
            replaceRecoverablePhase(.collectingInitial(collection))
        case .collecting(var collection):
            update(&collection)
            replaceRecoverablePhase(.collecting(collection))
        case .ready(let sequence, var collection):
            update(&collection)
            replaceRecoverablePhase(.ready(sequence, collection))
        }
    }

    private func replaceRecoverablePhase(_ nextRecovery: XDGConfigureRecoverablePhase) {
        switch phase {
        case .failed(let error, _):
            phase = .failed(error, recovery: nextRecovery)
        default:
            apply(nextRecovery)
        }
    }

    private func apply(_ recovery: XDGConfigureRecoverablePhase) {
        switch recovery {
        case .collectingInitial(let collection):
            phase = .collectingInitial(collection)
        case .collecting(let collection):
            phase = .collecting(collection)
        case .ready(let sequence, let collection):
            phase = .ready(sequence, collection)
        }
    }
}

extension XDGConfigureState: XDGSurfaceConfigureHandling {
    package func handleXDGSurfaceConfigure(serial: UInt32) {
        handleSurfaceConfigure(serial: serial)
    }
}
