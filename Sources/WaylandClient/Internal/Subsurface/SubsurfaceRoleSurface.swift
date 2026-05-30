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
    private var synchronizationMode: SubsurfaceSynchronizationMode
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
        synchronizationMode = subsurfaceConfiguration.synchronizationMode

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
    ) throws -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        return try present(damage: damage, draw)
    }

    package func redrawOnOwnerThread(
        damage: SurfaceDamageRegion?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        return try present(damage: damage, draw)
    }

    package func requestRedrawOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return }
        needsRedrawStorage = true
    }

    package func setInputRegionOnOwnerThread(_ region: SurfaceRegion?) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        return try applySurfaceRegion(region) { surface, rawRegion in
            surface.setInputRegion(rawRegion)
        }
    }

    package func setOpaqueRegionOnOwnerThread(_ region: SurfaceRegion?) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        return try applySurfaceRegion(region) { surface, rawRegion in
            surface.setOpaqueRegion(rawRegion)
        }
    }

    package func setPositionOnOwnerThread(_ newPosition: LogicalOffset)
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return nil }
        position = newPosition
        subsurface.setPosition(x: newPosition.x, y: newPosition.y)
        return parentCommitRequirement(reason: .positionChanged)
    }

    package func placeAboveOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        try requireValidStackingSibling(sibling)
        guard !isClosed else { throw ClientError.display(.closedSubsurface) }
        guard !sibling.isClosed else { throw ClientError.display(.closedSubsurface) }
        subsurface.placeAbove(sibling.surface)
        return parentCommitRequirement(reason: .stackingChanged)
    }

    package func placeBelowOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        try requireValidStackingSibling(sibling)
        guard !isClosed else { throw ClientError.display(.closedSubsurface) }
        guard !sibling.isClosed else { throw ClientError.display(.closedSubsurface) }
        subsurface.placeBelow(sibling.surface)
        return parentCommitRequirement(reason: .stackingChanged)
    }

    package func setSynchronizedOnOwnerThread() -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return nil }
        synchronizationMode = .synchronized
        subsurface.setSynchronized()
        return parentCommitRequirement(reason: .synchronizationModeChanged)
    }

    package func setDesynchronizedOnOwnerThread() -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        guard !isClosed else { return nil }
        synchronizationMode = .desynchronized
        subsurface.setDesynchronized()
        return parentCommitRequirement(reason: .synchronizationModeChanged)
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
        synchronizationMode = mode
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
    ) throws -> SubsurfaceParentCommitRequirement? {
        guard !isClosed else { return nil }
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
        return synchronizedStateCommitRequirement()
    }

    private func present(
        damage: SurfaceDamageRegion?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> SubsurfaceParentCommitRequirement? {
        guard !isClosed else { return nil }

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
        return try handlePresentationFollowUp(result.followUp)
    }

    private func handlePresentationFollowUp(
        _ followUp: WindowSoftwarePresentationFollowUp?
    ) throws -> SubsurfaceParentCommitRequirement? {
        guard let followUp else { return nil }

        switch followUp {
        case .succeeded:
            needsRedrawStorage = false
            return synchronizedStateCommitRequirement()
        case .blockedByBuffer:
            needsRedrawStorage = true
            return nil
        case .resetTransientState:
            surfaceRuntime.resetTransientTransactionState()
            needsRedrawStorage = true
            return nil
        case .fail(_, let error):
            throw ClientError.display(
                .subsurfacePresentationFailed(
                    SubsurfacePresentationFailure(
                        subsurfaceID: SubsurfaceIdentity(id),
                        reason: error.description
                    )
                ))
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

    private func requireValidStackingSibling(_ sibling: SubsurfaceRoleSurface) throws {
        guard id != sibling.id else {
            throw ClientError.display(
                .invalidSubsurfaceStacking(
                    .selfReference(SubsurfaceIdentity(id))
                ))
        }

        guard parentWindowID == sibling.parentWindowID else {
            throw ClientError.display(
                .invalidSubsurfaceStacking(
                    .differentParent(
                        subsurface: SubsurfaceIdentity(id),
                        sibling: SubsurfaceIdentity(sibling.id)
                    )
                ))
        }
    }

    private func synchronizedStateCommitRequirement() -> SubsurfaceParentCommitRequirement? {
        guard synchronizationMode == .synchronized else { return nil }
        return parentCommitRequirement(reason: .synchronizedSurfaceState)
    }

    private func parentCommitRequirement(
        reason: SubsurfaceParentCommitReason
    ) -> SubsurfaceParentCommitRequirement {
        SubsurfaceParentCommitRequirement(
            parentWindowID: parentWindowID,
            subsurfaceID: id,
            reason: reason
        )
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
