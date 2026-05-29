import WaylandRaw

private struct SubsurfaceRoleResources {
    let surface: RawSurface
    let subsurface: RawSubsurface

    func destroy() {
        subsurface.destroy()
        surface.destroy()
    }
}

package final class SubsurfaceRoleSurface {
    package let id: SubsurfaceID
    package let parentWindowID: WindowID

    private let connection: RawDisplayConnection
    private let bufferCount: PositiveInt
    private var position: LogicalOffset
    private var size: PositiveLogicalSize
    private var isClosed = false
    private var needsRedrawStorage = true
    private var surfaceRuntime: SurfaceRuntime<SubsurfaceRoleResources>
    private var pendingFrameRegistration: FrameCallbackRegistration?
    private var onOutputMembershipChanged: (([OutputID]) -> Void)?

    package init(
        id subsurfaceID: SubsurfaceID,
        parent parentWindow: TopLevelWindow,
        connection rawConnection: RawDisplayConnection,
        configuration subsurfaceConfiguration: SubsurfaceConfiguration
    ) throws {
        id = subsurfaceID
        parentWindowID = parentWindow.id
        connection = rawConnection
        bufferCount = subsurfaceConfiguration.bufferCount
        position = subsurfaceConfiguration.position
        size = subsurfaceConfiguration.size

        let globals = try rawConnection.bindRequiredGlobals()
        let rawObjects = try rawConnection.createManagedSubsurface(
            parent: parentWindow.rawSurfaceOnOwnerThread
        )
        surfaceRuntime = SurfaceRuntime(
            role: .subsurface,
            surfaceID: rawObjects.surface.objectID
        )

        do {
            installCapabilities(globals: globals)
            try installScaleObjects(globals: globals, surface: rawObjects.surface)
            try surfaceRuntime.installRoleResources(
                SubsurfaceRoleResources(
                    surface: rawObjects.surface,
                    subsurface: rawObjects.subsurface
                )
            )
            rawObjects.subsurface.setPosition(
                x: subsurfaceConfiguration.position.x,
                y: subsurfaceConfiguration.position.y
            )
            applySynchronizationMode(subsurfaceConfiguration.synchronizationMode)
            rawObjects.surface.commit()
        } catch {
            rawObjects.subsurface.destroy()
            rawObjects.surface.destroy()
            throw error
        }
    }

    deinit {
        close()
    }

    package var surfaceID: RawObjectID {
        connection.preconditionIsOwnerThread()
        return surface.objectID
    }

    package var isClosedOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return isClosed
    }

    package var needsRedrawOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return needsRedrawStorage
    }

    package var geometryOnOwnerThread: SurfaceGeometry {
        get throws {
            connection.preconditionIsOwnerThread()
            return try currentGeometry()
        }
    }

    package func showOnOwnerThread(
        damage: SurfaceDamageRegion?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()
        try present(damage: damage, draw)
    }

    package func redrawOnOwnerThread(
        damage: SurfaceDamageRegion?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()
        try present(damage: damage, draw)
    }

    package func requestRedrawOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return }
        needsRedrawStorage = true
    }

    package func setInputRegionOnOwnerThread(_ region: SurfaceRegion?) throws {
        connection.preconditionIsOwnerThread()
        try applySurfaceRegion(region) { surface, rawRegion in
            surface.setInputRegion(rawRegion)
        }
    }

    package func setOpaqueRegionOnOwnerThread(_ region: SurfaceRegion?) throws {
        connection.preconditionIsOwnerThread()
        try applySurfaceRegion(region) { surface, rawRegion in
            surface.setOpaqueRegion(rawRegion)
        }
    }

    package func setPositionOnOwnerThread(_ newPosition: LogicalOffset) {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return }
        position = newPosition
        subsurface.setPosition(x: newPosition.x, y: newPosition.y)
    }

    package func placeAboveOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws {
        connection.preconditionIsOwnerThread()
        try requireSameParent(as: sibling)
        guard !isClosed else { throw ClientError.display(.closedSubsurface) }
        guard !sibling.isClosed else { throw ClientError.display(.closedSubsurface) }
        subsurface.placeAbove(sibling.surface)
    }

    package func placeBelowOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws {
        connection.preconditionIsOwnerThread()
        try requireSameParent(as: sibling)
        guard !isClosed else { throw ClientError.display(.closedSubsurface) }
        guard !sibling.isClosed else { throw ClientError.display(.closedSubsurface) }
        subsurface.placeBelow(sibling.surface)
    }

    package func setSynchronizedOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return }
        subsurface.setSynchronized()
    }

    package func setDesynchronizedOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return }
        subsurface.setDesynchronized()
    }

    package func closeOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        close()
    }
}

extension SubsurfaceRoleSurface {
    private var roleResources: SubsurfaceRoleResources? {
        get { surfaceRuntime.roleResources }
        set { surfaceRuntime.roleResources = newValue }
    }

    private var scaleInstallation: SurfaceScaleInstallation {
        get { surfaceRuntime.scaleInstallation }
        set { surfaceRuntime.scaleInstallation = newValue }
    }

    private var surface: RawSurface {
        guard let surface = roleResources?.surface else {
            preconditionFailure("Subsurface surface used after destruction")
        }
        return surface
    }

    private var subsurface: RawSubsurface {
        guard let subsurface = roleResources?.subsurface else {
            preconditionFailure("Subsurface role used after destruction")
        }
        return subsurface
    }

    private func installCapabilities(globals: BoundGlobals) {
        surfaceRuntime.setPresentationFeedbackCapability(
            globals.extensions.presentation.presentationFeedbackCapabilityStatus
        )
        surfaceRuntime.setDmabufAdvertisement(
            globals.extensions.linuxDmabuf.surfaceDmabufAdvertisement
        )
        surfaceRuntime.setSynchronizationCapability(
            globals.extensions.surfaceSynchronizationCapability
        )
        surfaceRuntime.setPacingCapability(globals.extensions.surfacePacingCapability)
        surfaceRuntime.setContentTypeCapability(globals.extensions.surfaceContentTypeCapability)
        surfaceRuntime.setAlphaModifierCapability(globals.extensions.surfaceAlphaModifierCapability)
        surfaceRuntime.setTearingControlCapability(
            globals.extensions.surfaceTearingControlCapability)
        surfaceRuntime.setColorRepresentationCapability(
            globals.extensions.surfaceColorRepresentationCapability
        )
        surfaceRuntime.setColorCapability(globals.extensions.surfaceColorCapability)
    }

    private func installScaleObjects(globals: BoundGlobals, surface: RawSurface) throws {
        scaleInstallation = try SurfaceScaleInstallation.install(
            globals: globals,
            surface: surface,
            invariantFailureSink: connection.invariantFailureSink,
            callbacks: SurfaceScaleInstallationCallbacks(
                onPreferredBufferScale: { [weak self] factor in
                    self?.handlePreferredBufferScale(factor)
                },
                onPreferredFractionalScale: { [weak self] scale in
                    self?.handlePreferredFractionalScale(scale)
                },
                onFractionalScaleUnavailable: {
                    // Subsurfaces fall back to integer scale when viewporter is unavailable.
                },
                onOutputEnter: { [weak self] output in
                    self?.handleSurfaceEnteredOutput(output)
                },
                onOutputLeave: { [weak self] output in
                    self?.handleSurfaceLeftOutput(output)
                }
            )
        )
    }

    private func applySynchronizationMode(_ mode: SubsurfaceSynchronizationMode) {
        switch mode {
        case .synchronized:
            subsurface.setSynchronized()
        case .desynchronized:
            subsurface.setDesynchronized()
        }
    }

    private func applySurfaceRegion(
        _ region: SurfaceRegion?,
        setRegion: (RawSurface, RawRegion?) -> Void
    ) throws {
        guard !isClosed else { return }
        guard let globals = connection.boundGlobals else {
            throw ClientError.windowCreationFailed(.requiredGlobalsNotBound)
        }

        try SurfaceRegionApplicator.apply(
            region,
            compositor: globals.compositor
        ) { rawRegion in
            setRegion(surface, rawRegion)
        }
        surface.commit()
    }

    private func present(
        damage: SurfaceDamageRegion?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        guard !isClosed else { return }

        let generation = surfaceRuntime.nextCommitGeneration
        let request = PresentationRequest(
            generation: generation,
            configuration: resolvedConfiguration()
        )
        let result = try WindowSoftwarePresenter(
            surface: surface,
            scaleInstallation: scaleInstallation,
            createSharedMemoryPool: { [self] bufferSize in
                guard let globals = connection.boundGlobals else {
                    throw ClientError.windowCreationFailed(.requiredGlobalsNotBound)
                }

                return try globals.sharedMemory.createPool(
                    width: bufferSize.width.rawValue,
                    height: bufferSize.height.rawValue,
                    bufferCount: bufferCount.rawValue
                ) { [weak self] in
                    self?.handleBufferReleased()
                }
            },
            isWindowClosed: { [self] in isClosed },
            onFrame: { [weak self] in
                self?.handleFrameDone()
            }
        ).present(
            context: WindowSoftwarePresentationContext(
                request: request,
                geometry: try currentGeometry(),
                metadata: .default,
                damage: damage,
                presentationFeedback: nil
            ),
            draw: draw,
            runtime: &surfaceRuntime,
            pendingFrameRegistration: &pendingFrameRegistration
        )
        try handlePresentationFollowUp(result.followUp)
    }

    private func handlePresentationFollowUp(
        _ followUp: WindowSoftwarePresentationFollowUp?
    ) throws {
        guard let followUp else { return }

        switch followUp {
        case .succeeded:
            needsRedrawStorage = false
        case .blockedByBuffer:
            needsRedrawStorage = true
        case .resetTransientState:
            surfaceRuntime.resetTransientTransactionState()
            needsRedrawStorage = true
        case .fail(_, let error):
            throw ClientError.invalidWindowState(
                .message("subsurface presentation failed: \(error.description)")
            )
        }
    }

    private func currentGeometry() throws -> SurfaceGeometry {
        do {
            return try scaleInstallation.geometry(logicalSize: size)
        } catch let error as WindowError {
            throw ClientError.window(parentWindowID, error)
        }
    }

    private func resolvedConfiguration() -> ResolvedWindowConfiguration {
        ResolvedWindowConfiguration(
            serial: 0,
            size: size,
            states: [],
            bounds: nil,
            wmCapabilities: [],
            decorationMode: nil
        )
    }

    private func handleFrameDone() {
        do {
            _ = try surfaceRuntime.completeFrameCallback()
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
        pendingFrameRegistration = nil
        surfaceRuntime.dropReleasedRetiredBufferPools()
        guard !isClosed else { return }
        if needsRedrawStorage {
            onOutputMembershipChanged?(currentOutputIDsOnOwnerThread())
        }
    }

    private func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        surfaceRuntime.dropReleasedRetiredBufferPools()
    }

    private func handlePreferredBufferScale(_ factor: Int32) {
        guard !isClosed else { return }
        do {
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredBufferScale(
                        factor,
                        logicalSize: size
                    )
                })
            else { return }
            needsRedrawStorage = true
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func handlePreferredFractionalScale(_ scale: UInt32) {
        guard !isClosed else { return }
        do {
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredFractionalScale(
                        scale,
                        logicalSize: size
                    )
                })
            else { return }
            needsRedrawStorage = true
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func handleSurfaceEnteredOutput(_ output: RawOutputPointerIdentity) {
        guard !isClosed else { return }
        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }
        guard surfaceRuntime.enterOutput(outputID) else { return }
        onOutputMembershipChanged?(currentOutputIDsOnOwnerThread())
    }

    private func handleSurfaceLeftOutput(_ output: RawOutputPointerIdentity) {
        guard !isClosed else { return }
        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }
        guard surfaceRuntime.leaveOutput(outputID) else { return }
        onOutputMembershipChanged?(currentOutputIDsOnOwnerThread())
    }

    private func currentOutputIDsOnOwnerThread() -> [OutputID] {
        connection.preconditionIsOwnerThread()
        guard let outputRegistry = connection.boundGlobals?.outputRegistry else { return [] }

        return surfaceRuntime.currentOutputIDs { outputRegistry.output(for: $0) != nil }
    }

    private func requireSameParent(as sibling: SubsurfaceRoleSurface) throws {
        guard parentWindowID == sibling.parentWindowID else {
            throw ClientError.invalidWindowState(
                .message("subsurface sibling belongs to another parent window")
            )
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        needsRedrawStorage = false
        pendingFrameRegistration = nil
        surfaceRuntime.cancelFrameCallback()
        surfaceRuntime.retireSharedMemoryPools(reason: .windowClosed)
        surfaceRuntime.destroyScaleInstallation()
        let removedRoleResources = surfaceRuntime.removeRoleResources()
        removedRoleResources?.destroy()
        try? surfaceRuntime.markSurfaceDestroyed()
    }
}
