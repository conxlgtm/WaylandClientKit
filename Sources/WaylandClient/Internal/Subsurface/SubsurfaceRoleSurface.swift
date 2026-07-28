import WaylandRaw

struct SubsurfaceRoleResources {
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

    let connection: RawDisplayConnection
    let bufferCount: PositiveInt
    var size: PositiveLogicalSize
    var model: SubsurfaceModel
    let softwarePresentationCoordinator =
        SoftwareSurfaceReservationCoordinator<PendingSubsurfaceSoftwareFrameReservation>(
            reservation: { $0.reservedFrame.reservation },
            retire: { $0.reservedFrame.drawingBuffer.discard() }
        )
    let presentationFeedbackCoordinator = SurfacePresentationFeedbackCoordinator()
    var surfaceRuntime: SurfaceRuntime<SubsurfaceRoleResources>
    var pendingFrameRegistration: FrameCallbackRegistration?
    var onRedrawRequested: (() -> Void)?
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
        size = subsurfaceConfiguration.size
        model = SubsurfaceModel(
            synchronizationMode: subsurfaceConfiguration.synchronizationMode
        )

        let globals = try rawConnection.bindRequiredGlobals()
        let rawObjects = try rawConnection.createManagedSubsurface(
            parent: parentWindow.rawSurfaceOnOwnerThread
        )
        surfaceRuntime = SurfaceRuntime(
            role: .subsurface,
            surfaceID: rawObjects.surface.objectID
        )
        surfaceRuntime.markConfigureIndependentRoleReady()

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
        closeOnOwnerThread()
    }

    package var isClosedOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return model.lifecycle == .closed
    }

    package var needsRedrawOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return model.redraw.isDirty
    }

    package var geometryOnOwnerThread: SurfaceGeometry {
        get throws {
            connection.preconditionIsOwnerThread()
            return try currentGeometry()
        }
    }

    package func requestRedrawOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        guard model.lifecycle == .active else { return }
        try interpretSubsurfaceEffects(
            model.reduce(
                .contentInvalidated(bufferAvailability: try redrawBufferAvailability())
            )
        )
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
        guard model.lifecycle == .active else { return nil }
        subsurface.setPosition(x: newPosition.x, y: newPosition.y)
        return parentCommitRequirement(reason: .positionChanged)
    }

    package func placeAboveOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        try requireValidStackingSibling(sibling)
        guard model.lifecycle == .active else { throw ClientError.display(.closedSubsurface) }
        guard sibling.model.lifecycle == .active else {
            throw ClientError.display(.closedSubsurface)
        }
        subsurface.placeAbove(sibling.surface)
        return parentCommitRequirement(reason: .stackingChanged)
    }

    package func placeBelowOnOwnerThread(_ sibling: SubsurfaceRoleSurface) throws
        -> SubsurfaceParentCommitRequirement?
    {
        connection.preconditionIsOwnerThread()
        try requireValidStackingSibling(sibling)
        guard model.lifecycle == .active else { throw ClientError.display(.closedSubsurface) }
        guard sibling.model.lifecycle == .active else {
            throw ClientError.display(.closedSubsurface)
        }
        subsurface.placeBelow(sibling.surface)
        return parentCommitRequirement(reason: .stackingChanged)
    }

    package func setSynchronizedOnOwnerThread() throws -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        guard model.lifecycle == .active else { return nil }
        let bufferAvailability = try redrawBufferAvailability()
        subsurface.setSynchronized()
        try interpretSubsurfaceEffects(
            model.reduce(
                .synchronizationModeChanged(
                    .synchronized,
                    bufferAvailability: bufferAvailability
                )
            )
        )
        return nil
    }

    package func setDesynchronizedOnOwnerThread() throws -> SubsurfaceParentCommitRequirement? {
        connection.preconditionIsOwnerThread()
        guard model.lifecycle == .active else { return nil }
        let bufferAvailability = try redrawBufferAvailability()
        subsurface.setDesynchronized()
        try interpretSubsurfaceEffects(
            model.reduce(
                .synchronizationModeChanged(
                    .desynchronized,
                    bufferAvailability: bufferAvailability
                )
            )
        )
        return nil
    }

    package func closeOnOwnerThread(parentWindowClosed: Bool = false) {
        connection.preconditionIsOwnerThread()
        do {
            try interpretSubsurfaceEffects(
                model.reduce(parentWindowClosed ? .parentWindowClosed : .explicitClose)
            )
        } catch {
            assertionFailure("subsurface close transition failed: \(error)")
        }
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

    var surface: RawSurface {
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
    ) throws -> SubsurfaceParentCommitRequirement? {
        guard model.lifecycle == .active else { return nil }
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

    func currentGeometry() throws -> SurfaceGeometry {
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

    func handleFrameDone() {
        do {
            _ = try surfaceRuntime.completeFrameCallback()
            pendingFrameRegistration = nil
            surfaceRuntime.dropReleasedRetiredBufferPools()
            guard model.lifecycle == .active else { return }
            try interpretSubsurfaceEffects(
                model.reduce(
                    .frameBecameReady(bufferAvailability: try redrawBufferAvailability())
                )
            )
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        surfaceRuntime.dropReleasedRetiredBufferPools()
        guard model.lifecycle == .active else { return }
        do {
            try interpretSubsurfaceEffects(
                model.reduce(
                    .bufferBecameAvailable(bufferAvailability: try redrawBufferAvailability())
                )
            )
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func handlePreferredBufferScale(_ factor: Int32) {
        guard model.lifecycle == .active else { return }
        do {
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredBufferScale(
                        factor,
                        logicalSize: size
                    )
                })
            else { return }
            try interpretSubsurfaceEffects(
                model.reduce(.scaleChanged(bufferAvailability: try redrawBufferAvailability()))
            )
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func handlePreferredFractionalScale(_ scale: UInt32) {
        guard model.lifecycle == .active else { return }
        do {
            guard
                try surfaceRuntime.updateScaleInstallation({ scaleInstallation in
                    try scaleInstallation.updatePreferredFractionalScale(
                        scale,
                        logicalSize: size
                    )
                })
            else { return }
            try interpretSubsurfaceEffects(
                model.reduce(.scaleChanged(bufferAvailability: try redrawBufferAvailability()))
            )
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func handleSurfaceEnteredOutput(_ output: RawOutputPointerIdentity) {
        guard model.lifecycle == .active else { return }
        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }
        guard surfaceRuntime.enterOutput(outputID) else { return }
        onOutputMembershipChanged?(currentOutputIDsOnOwnerThread())
    }

    private func handleSurfaceLeftOutput(_ output: RawOutputPointerIdentity) {
        guard model.lifecycle == .active else { return }
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
        SubsurfaceParentCommitPolicy.requirement(
            parentWindowID: parentWindowID,
            subsurfaceID: id,
            event: .surfaceStateCommitted(model.synchronizationMode)
        )
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
}
