import WaylandRaw

package struct SurfaceScaleInstallationCallbacks {
    package let onPreferredBufferScale: (Int32) -> Void
    package let onPreferredFractionalScale: (UInt32) -> Void
    package let onFractionalScaleUnavailable: () -> Void
    package let onOutputEnter: (RawOutputPointerIdentity) -> Void
    package let onOutputLeave: (RawOutputPointerIdentity) -> Void

    package init(
        onPreferredBufferScale handlePreferredBufferScale: @escaping (Int32) -> Void,
        onPreferredFractionalScale handlePreferredFractionalScale: @escaping (UInt32) -> Void,
        onFractionalScaleUnavailable handleFractionalScaleUnavailable: @escaping () -> Void,
        onOutputEnter handleOutputEnter: @escaping (RawOutputPointerIdentity) -> Void = { _ in () },
        onOutputLeave handleOutputLeave: @escaping (RawOutputPointerIdentity) -> Void = { _ in () }
    ) {
        onPreferredBufferScale = handlePreferredBufferScale
        onPreferredFractionalScale = handlePreferredFractionalScale
        onFractionalScaleUnavailable = handleFractionalScaleUnavailable
        onOutputEnter = handleOutputEnter
        onOutputLeave = handleOutputLeave
    }
}

package enum SurfaceScaleInstallation {
    package struct FractionalResources {
        let owner: RawSurfaceScaleOwner
        let viewport: RawViewport
        let fractionalScale: RawFractionalScale
        let fractionalOwner: RawFractionalScaleOwner

        func setViewportDestination(_ destination: PositiveLogicalSize) {
            viewport.setDestination(
                width: destination.width.rawValue,
                height: destination.height.rawValue
            )
        }

        func destroy() {
            owner.cancel()
            fractionalOwner.cancel()
            fractionalScale.destroy()
            viewport.destroy()
        }
    }

    private struct RawFractionalScaleAcquisitionFactory: FractionalScaleAcquisitionFactory {
        let viewporter: RawViewporter
        let manager: RawFractionalScaleManager
        let surface: RawSurface
        let invariantFailureSink: RawInvariantFailureSink?
        let surfaceScaleOwner: RawSurfaceScaleOwner
        let onPreferredFractionalScale: (UInt32) -> Void

        func createViewport() throws -> RawViewport {
            try viewporter.getViewport(for: surface)
        }

        func createFractionalScale() throws -> RawFractionalScale {
            try manager.getFractionalScale(for: surface)
        }

        func createOwner() -> RawFractionalScaleOwner {
            RawFractionalScaleOwner(
                onPreferredScale: onPreferredFractionalScale,
                invariantFailureSink: invariantFailureSink
            )
        }

        func installOwner(
            _ owner: RawFractionalScaleOwner,
            on scale: RawFractionalScale
        ) throws {
            try owner.install(on: scale)
        }

        func destroyViewport(_ viewport: RawViewport) {
            viewport.destroy()
        }

        func destroyFractionalScale(_ scale: RawFractionalScale) {
            scale.destroy()
        }

        func cancelOwner(_ owner: RawFractionalScaleOwner) {
            owner.cancel()
        }

        func makeResources(
            viewport: RawViewport,
            fractionalScale: RawFractionalScale,
            owner: RawFractionalScaleOwner
        ) -> FractionalResources {
            FractionalResources(
                owner: surfaceScaleOwner,
                viewport: viewport,
                fractionalScale: fractionalScale,
                fractionalOwner: owner
            )
        }
    }

    case inactive(SurfaceScaleState)
    case integer(owner: RawSurfaceScaleOwner, state: SurfaceScaleState)
    case fractional(resources: FractionalResources, state: SurfaceScaleState)

    private var state: SurfaceScaleState {
        switch self {
        case .inactive(let state),
            .integer(_, let state),
            .fractional(_, let state):
            state
        }
    }

    package var capability: SurfaceScaleCapability {
        state.capability
    }

    package init() {
        self = .inactive(SurfaceScaleState())
    }

    package static func install(
        globals: BoundGlobals,
        surface: RawSurface,
        invariantFailureSink: RawInvariantFailureSink?,
        callbacks: SurfaceScaleInstallationCallbacks
    ) throws -> SurfaceScaleInstallation {
        let newSurfaceScaleOwner = RawSurfaceScaleOwner(
            onPreferredBufferScale: callbacks.onPreferredBufferScale,
            onOutputEnter: callbacks.onOutputEnter,
            onOutputLeave: callbacks.onOutputLeave,
            invariantFailureSink: invariantFailureSink
        )
        try newSurfaceScaleOwner.install(on: surface)

        return try ScaleInstallationAcquisition.install(
            surfaceScaleOwner: newSurfaceScaleOwner,
            makeInstallation: { surfaceScaleOwner in
                try makeInstallation(
                    globals: globals,
                    surface: surface,
                    invariantFailureSink: invariantFailureSink,
                    surfaceScaleOwner: surfaceScaleOwner,
                    callbacks: callbacks
                )
            },
            cancelSurfaceScaleOwner: { owner in
                owner.cancel()
            }
        )
    }

    package mutating func updatePreferredBufferScale(
        _ factor: Int32,
        logicalSize: PositiveLogicalSize
    ) throws -> Bool {
        var nextState = state
        let changed = try nextState.updatePreferredBufferScale(
            factor,
            logicalSize: logicalSize
        )
        replaceState(nextState)
        return changed
    }

    package mutating func updatePreferredFractionalScale(
        _ scale: UInt32,
        logicalSize: PositiveLogicalSize
    ) throws -> Bool {
        var nextState = state
        let changed = try nextState.updatePreferredFractionalScale(
            scale,
            logicalSize: logicalSize
        )
        replaceState(nextState)
        return changed
    }

    package func geometry(logicalSize: PositiveLogicalSize) throws -> SurfaceGeometry {
        try state.geometry(logicalSize: logicalSize)
    }

    package func commitPlan(
        geometry: SurfaceGeometry,
        damageMode: DamageCoordinateMode
    ) -> SurfaceCommitPlan {
        state.commitPlan(
            geometry: geometry,
            damageMode: damageMode
        )
    }

    package func applyViewportDestinationIfNeeded(_ destination: PositiveLogicalSize?) {
        guard let destination else { return }

        guard case .fractional(let resources, _) = self else {
            preconditionFailure(
                "fractional scale commit plan requires a viewport installation"
            )
        }

        resources.setViewportDestination(destination)
    }

    package mutating func destroy() {
        let preservedState = state

        switch self {
        case .inactive:
            break
        case .integer(let owner, _):
            owner.cancel()
        case .fractional(let resources, _):
            resources.destroy()
        }

        self = .inactive(preservedState)
    }

    private static func makeInstallation(
        globals: BoundGlobals,
        surface: RawSurface,
        invariantFailureSink: RawInvariantFailureSink?,
        surfaceScaleOwner newSurfaceScaleOwner: RawSurfaceScaleOwner,
        callbacks: SurfaceScaleInstallationCallbacks
    ) throws -> SurfaceScaleInstallation {
        switch (globals.extensions.viewporter, globals.extensions.fractionalScaleManager) {
        case (.bound(let boundViewporter), .bound(let boundManager)):
            let resources = try ScaleInstallationAcquisition.acquireFractionalResources(
                using: RawFractionalScaleAcquisitionFactory(
                    viewporter: boundViewporter,
                    manager: boundManager,
                    surface: surface,
                    invariantFailureSink: invariantFailureSink,
                    surfaceScaleOwner: newSurfaceScaleOwner,
                    onPreferredFractionalScale: callbacks.onPreferredFractionalScale
                )
            )
            return .fractional(
                resources: resources,
                state: SurfaceScaleState(capability: .fractional)
            )
        case (.missing, .bound):
            callbacks.onFractionalScaleUnavailable()
            return .integer(
                owner: newSurfaceScaleOwner,
                state: SurfaceScaleState(capability: .integerOnly)
            )
        case (.bound, .missing),
            (.missing, .missing):
            return .integer(
                owner: newSurfaceScaleOwner,
                state: SurfaceScaleState(capability: .integerOnly)
            )
        }
    }

    private mutating func replaceState(_ nextState: SurfaceScaleState) {
        switch self {
        case .inactive:
            self = .inactive(nextState)
        case .integer(let owner, _):
            self = .integer(owner: owner, state: nextState)
        case .fractional(let resources, _):
            self = .fractional(
                resources: resources,
                state: nextState
            )
        }
    }
}
