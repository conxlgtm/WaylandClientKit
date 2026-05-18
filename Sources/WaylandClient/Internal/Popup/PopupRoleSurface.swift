import Glibc
import WaylandRaw

struct PopupRoleResources {
    let surface: RawSurface
    let xdgSurface: RawXDGSurface
    let popup: RawXDGPopup
    let xdgSurfaceOwner: XDGSurfaceOwner
    let positioner: RawXDGPositioner
    var popupOwner: XDGPopupOwner?

    mutating func destroy() {
        popupOwner?.cancel()
        popupOwner = nil
        xdgSurfaceOwner.cancel()
        popup.destroy()
        positioner.destroy()
        xdgSurface.destroy()
        surface.destroy()
    }
}

package final class PopupRoleSurface {
    package let id: PopupID
    package let parentWindowID: WindowID

    package let connection: RawDisplayConnection
    package let configuration: PopupConfiguration
    package let bufferCount: PositiveInt
    package let initialConfigurePump: (Int32) throws -> Void
    package let failureSink: any WindowFailureSink
    package let configureState = PopupConfigureState()

    var surfaceRuntime: SurfaceRuntime<PopupRoleResources>
    package var pendingFrameRegistration: FrameCallbackRegistration?
    package var model: PopupModel

    package var onClose: (() -> Void)?
    package var onDismissed: (() -> Void)?
    package var onClosed: (() -> Void)?
    package var onRedrawRequested: (() -> Void)?

    // swiftlint:disable:next function_body_length
    package init(
        id popupID: PopupID,
        parentWindowID popupParentWindowID: WindowID,
        connection rawConnection: RawDisplayConnection,
        parentXDGSurface: RawXDGSurface,
        configuration popupConfiguration: PopupConfiguration,
        bufferCount popupBufferCount: PositiveInt,
        failureSink popupFailureSink: any WindowFailureSink = DefaultWindowFailureSink(),
        initialConfigurePump pumpEvents: @escaping (Int32) throws -> Void
    ) throws {
        id = popupID
        parentWindowID = popupParentWindowID
        connection = rawConnection
        configuration = popupConfiguration
        bufferCount = popupBufferCount
        failureSink = popupFailureSink
        initialConfigurePump = pumpEvents
        model = PopupModel(
            id: popupID,
            parentWindowID: popupParentWindowID,
            fallbackSize: popupConfiguration.positioner.size
        )

        let globals = try rawConnection.bindRequiredGlobals()
        let newSurface = try globals.compositor.createSurface()
        surfaceRuntime = SurfaceRuntime(role: .popup, surfaceID: newSurface.objectID)
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
        surfaceRuntime.setContentTypeCapability(
            globals.extensions.surfaceContentTypeCapability
        )
        surfaceRuntime.setAlphaModifierCapability(
            globals.extensions.surfaceAlphaModifierCapability
        )
        surfaceRuntime.setTearingControlCapability(
            globals.extensions.surfaceTearingControlCapability
        )
        surfaceRuntime.setColorRepresentationCapability(
            globals.extensions.surfaceColorRepresentationCapability
        )
        surfaceRuntime.setColorCapability(globals.extensions.surfaceColorCapability)
        let newXDGSurface = try globals.xdgWMBase.getSurface(for: newSurface)
        let newPositioner = try globals.xdgWMBase.createPositioner()
        popupConfiguration.positioner.apply(to: newPositioner)
        let newPopup = try newXDGSurface.getPopup(
            parent: parentXDGSurface,
            positioner: newPositioner
        )
        let newXDGSurfaceOwner = XDGSurfaceOwner(
            configureHandler: configureState,
            invariantFailureSink: rawConnection.invariantFailureSink
        )

        do {
            try newXDGSurfaceOwner.install(on: newXDGSurface)
            try surfaceRuntime.installRoleResources(
                PopupRoleResources(
                    surface: newSurface,
                    xdgSurface: newXDGSurface,
                    popup: newPopup,
                    xdgSurfaceOwner: newXDGSurfaceOwner,
                    positioner: newPositioner
                )
            )
            try scaleInstallation = SurfaceScaleInstallation.install(
                globals: globals,
                surface: newSurface,
                invariantFailureSink: rawConnection.invariantFailureSink,
                callbacks: SurfaceScaleInstallationCallbacks(
                    onPreferredBufferScale: { [weak self] factor in
                        self?.handlePreferredBufferScale(factor)
                    },
                    onPreferredFractionalScale: { [weak self] scale in
                        self?.handlePreferredFractionalScale(scale)
                    },
                    onFractionalScaleUnavailable: {
                        // Popups fall back to integer scale when viewporter is unavailable.
                    },
                    onOutputEnter: { [weak self] output in
                        self?.handleSurfaceEnteredOutput(output)
                    },
                    onOutputLeave: { [weak self] output in
                        self?.handleSurfaceLeftOutput(output)
                    }
                )
            )
        } catch {
            newXDGSurfaceOwner.cancel()
            newPopup.destroy()
            newPositioner.destroy()
            newXDGSurface.destroy()
            newSurface.destroy()
            throw error
        }

        configureState.setSurfaceConfigureHandler { [weak self] in
            self?.markNeedsRedraw()
        }
        let activePopupOwner = XDGPopupOwner(
            onConfigure: { [configureState] configure in
                configureState.handlePopupConfigure(configure)
            },
            onPopupDone: { [weak self] in
                self?.handlePopupDone()
            },
            invariantFailureSink: rawConnection.invariantFailureSink
        )
        do {
            try activePopupOwner.install(on: popup)
            popupOwner = activePopupOwner
        } catch {
            close()
            throw error
        }

        do {
            try applyGrabIfNeeded(globals: globals)
            surface.commit()
            try interpretPopupEffects(model.reduce(.initialCommitSent))
        } catch {
            close()
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
        return model.isClosed
    }

    package var needsRedrawOnOwnerThread: Bool {
        connection.preconditionIsOwnerThread()
        return model.redraw.isDirty
    }

    package var geometryOnOwnerThread: SurfaceGeometry {
        get throws {
            connection.preconditionIsOwnerThread()
            return try currentSurfaceGeometry()
        }
    }

    package var placementOnOwnerThread: PopupPlacement {
        get throws {
            connection.preconditionIsOwnerThread()
            guard let currentPlacement = model.currentPlacement else {
                throw ClientError.display(.unknownPopup)
            }

            return currentPlacement
        }
    }

    package func showOnOwnerThread(
        timeoutMilliseconds: Int32,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()

        if model.currentPlacement == nil {
            _ = try waitForInitialConfigure(timeoutMilliseconds: timeoutMilliseconds)
        }

        try requestRedrawOnOwnerThread()
        _ = try drawAndPresent(draw)
    }

    package func redrawOnOwnerThread(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else { return }

        _ = try consumeLatestConfigureIfAvailable()
        _ = try drawAndPresent(draw)
    }

    package func requestRedrawOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try markNeedsRedraw(bufferAvailability: try redrawBufferAvailability())
    }

    package func closeOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        close()
    }
}

extension PopupRoleSurface {
    private var roleResources: PopupRoleResources? {
        get { surfaceRuntime.roleResources }
        set { surfaceRuntime.roleResources = newValue }
    }

    package var scaleInstallation: SurfaceScaleInstallation {
        get { surfaceRuntime.scaleInstallation }
        set { surfaceRuntime.scaleInstallation = newValue }
    }

    private var liveRoleResources: PopupRoleResources {
        guard let roleResources else {
            preconditionFailure("Popup role resources used after destruction")
        }

        return roleResources
    }

    package var surface: RawSurface {
        liveRoleResources.surface
    }

    package var xdgSurface: RawXDGSurface {
        liveRoleResources.xdgSurface
    }

    package var popup: RawXDGPopup {
        liveRoleResources.popup
    }

    package var positioner: RawXDGPositioner {
        liveRoleResources.positioner
    }

    package var popupOwner: XDGPopupOwner? {
        get { roleResources?.popupOwner }
        set { roleResources?.popupOwner = newValue }
    }

    package func destroyRoleResources() throws {
        var removedRoleResources = surfaceRuntime.removeRoleResources()
        removedRoleResources?.destroy()
        try surfaceRuntime.markSurfaceDestroyed()
    }

    package func destroyScaleResources() {
        surfaceRuntime.destroyScaleInstallation()
    }

    package func updateScaleResources(
        _ update: (inout SurfaceScaleInstallation) throws -> Bool
    ) rethrows -> Bool {
        try surfaceRuntime.updateScaleInstallation(update)
    }

    package func recordSurfaceConfigureReceived(serial: UInt32) {
        surfaceRuntime.recordConfigureReceived(serial: serial)
    }

    package func acknowledgeSurfaceConfigure(serial: UInt32) throws {
        try surfaceRuntime.acknowledgeConfigure(serial: serial)
    }

    package func requestSurfaceFrameCallback(
        generation: UInt64,
        onFrame: @escaping () -> Void
    ) throws -> FrameCallbackRegistration {
        try SurfaceFrameCommitter.requestFrameCallback(
            on: surface,
            runtime: &surfaceRuntime,
            generation: generation,
            onFrame: onFrame
        )
    }

    package func cancelSurfaceFrameCallback() {
        surfaceRuntime.cancelFrameCallback()
    }

    package func completeSurfaceFrameCallback() throws {
        _ = try surfaceRuntime.completeFrameCallback()
    }

    package func prepareSurfaceFrameCommit(
        generation: UInt64,
        geometry: SurfaceGeometry
    ) throws -> PreparedSurfaceFrameCommit {
        try SurfaceFrameCommitter.prepare(
            SurfaceFrameCommitRequest(
                surface: surface,
                scaleInstallation: scaleInstallation,
                generation: generation,
                geometry: geometry
            ),
            runtime: &surfaceRuntime,
        )
    }

    package func commitSurfaceFrame(
        _ preparedCommit: PreparedSurfaceFrameCommit,
        buffer: RawBuffer
    ) throws {
        try SurfaceFrameCommitter.commit(
            preparedCommit,
            buffer: buffer,
            runtime: &surfaceRuntime
        )
    }

    package func resetTransientSurfaceTransactionState() {
        surfaceRuntime.resetTransientTransactionState()
    }

    package func currentOutputIDsOnOwnerThread() -> [OutputID] {
        connection.preconditionIsOwnerThread()
        guard let outputRegistry = connection.boundGlobals?.outputRegistry else { return [] }

        return surfaceRuntime.currentOutputIDs { outputRegistry.output(for: $0) != nil }
    }

    private func handleSurfaceEnteredOutput(_ output: RawOutputPointerIdentity) {
        guard !model.isClosed else { return }

        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }

        _ = surfaceRuntime.enterOutput(outputID)
    }

    private func handleSurfaceLeftOutput(_ output: RawOutputPointerIdentity) {
        guard !model.isClosed else { return }

        guard
            let outputID = connection.boundGlobals?.outputRegistry.outputID(for: output)
        else {
            return
        }

        _ = surfaceRuntime.leaveOutput(outputID)
    }
}
