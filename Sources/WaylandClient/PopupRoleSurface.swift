import Glibc
import WaylandRaw

package final class PopupRoleSurface {
    package let id: PopupID
    package let parentWindowID: WindowID

    package let connection: RawDisplayConnection
    package let configuration: PopupConfiguration
    package let bufferCount: PositiveInt
    package let initialConfigurePump: (Int32) throws -> Void
    package let failureSink: any WindowFailureSink
    package let surface: RawSurface
    package let xdgSurface: RawXDGSurface
    package let popup: RawXDGPopup
    package let xdgSurfaceOwner: XDGSurfaceOwner
    package let positioner: RawXDGPositioner
    package let configureState = PopupConfigureState()

    package var popupOwner: XDGPopupOwner?
    package var scaleInstallation = SurfaceScaleInstallation()
    package var buffers: RawSharedMemoryPool?
    package var retiredBufferPools: [RawSharedMemoryPool] = []
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
            surface = newSurface
            xdgSurface = newXDGSurface
            popup = newPopup
            xdgSurfaceOwner = newXDGSurfaceOwner
            positioner = newPositioner
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
        try markNeedsRedraw(bufferAvailable: try redrawBufferAvailable())
    }

    package func closeOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        close()
    }
}
