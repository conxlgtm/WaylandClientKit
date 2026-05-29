package struct PopupEventCallbacks {
    package let onDismissed: () -> Void
    package let onClosed: () -> Void
    package let onRedrawRequested: () -> Void
}

extension DisplayCore {
    func createPopup(
        parent windowID: WindowID,
        configuration popupConfiguration: PopupConfiguration
    ) throws -> PopupID {
        try withFatalFailureFinalization {
            try createPopupAfterFatalFailureGuard(
                parent: windowID,
                configuration: popupConfiguration
            )
        }
    }

    private func createPopupAfterFatalFailureGuard(
        parent windowID: WindowID,
        configuration popupConfiguration: PopupConfiguration
    ) throws -> PopupID {
        let parentWindow = try requireOpenWindow(windowID)
        let parentSurfaceID = try requireWindowSurfaceID(windowID)
        let popup = try requireSession().createPopupOnOwnerThread(
            parent: parentWindow,
            configuration: popupConfiguration,
            failureSink: WeakWindowFailureSink(self)
        )
        guard !isClosed else {
            popup.closeOnOwnerThread()
            throw ClientError.display(.closed)
        }
        try registerPopup(popup, surfaceParent: parentSurfaceID)
        return popup.id
    }

    private func registerPopup(
        _ popup: PopupRoleSurface,
        surfaceParent parentSurfaceID: SurfaceID
    ) throws {
        let popupSurfaceID = SurfaceID(rawObjectID: popup.surfaceID)
        do {
            let parentWindowID = try surfaces.insertPopup(
                popup,
                surfaceID: popupSurfaceID,
                parent: parentSurfaceID
            )
            installPopupEventCallbacks(for: popup, parentWindowID: parentWindowID)
        } catch {
            popup.closeOnOwnerThread()
            throw error
        }
        assertSurfaceStoreInvariants()
    }

    private func installPopupEventCallbacks(
        for popup: PopupRoleSurface,
        parentWindowID: WindowID
    ) {
        let callbacks = popupEventCallbacks(popupID: popup.id, parentWindowID: parentWindowID)
        let popupSurfaceID = popup.surfaceID
        popup.onDismissed = callbacks.onDismissed
        popup.onClosed = callbacks.onClosed
        popup.onRedrawRequested = callbacks.onRedrawRequested
        popup.onOutputMembershipChanged = { [weak core = self] outputs in
            guard let core, core.surfaceGraphAcceptsLifecycleCallback() else { return }
            do {
                try core.activeSession?.updateCursorOutputScalesOnOwnerThread(
                    surfaceID: popupSurfaceID,
                    outputIDs: outputs
                )
            } catch {
                core.markSurfaceStoreInvariantFailed(error)
            }
        }
    }

    func showPopup(
        _ popupID: PopupID,
        timeoutMilliseconds: Int32,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let popup = try requireOpenPopup(popupID)
            try popup.showOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds, draw)
            guard !isClosed, let activeSession else { return }
            publishSessionEvents(activeSession)
        }
    }

    func redrawPopup(
        _ popupID: PopupID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).redrawOnOwnerThread(draw)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func setPopupInputRegion(_ popupID: PopupID, _ region: SurfaceRegion?) throws {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).setInputRegionOnOwnerThread(region)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func setPopupOpaqueRegion(_ popupID: PopupID, _ region: SurfaceRegion?) throws {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).setOpaqueRegionOnOwnerThread(region)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func popupIsClosed(_ popupID: PopupID) throws -> Bool {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            if surfaces.popupIsClosedOrClosing(popupID) {
                return true
            }

            return try requirePopup(popupID).isClosedOnOwnerThread
        }
    }

    func popupNeedsRedraw(_ popupID: PopupID) throws -> Bool {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).needsRedrawOnOwnerThread
        }
    }

    func popupGeometry(_ popupID: PopupID) throws -> SurfaceGeometry {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).geometryOnOwnerThread
        }
    }

    func popupPlacement(_ popupID: PopupID) throws -> PopupPlacement {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).placementOnOwnerThread
        }
    }

    func requestPopupRedraw(_ popupID: PopupID) throws {
        try withFatalFailureFinalization {
            try requireOpenPopup(popupID).requestRedrawOnOwnerThread()
        }
    }

    func closePopup(_ popupID: PopupID) {
        withFatalFailureFinalization {
            // Fatal raw invariants already finished streams and deferred graph cleanup.
            guard !hasPendingFatalFailure else { return }
            guard !surfaces.popupIsClosedOrClosing(popupID) else { return }
            guard surfaces.popup(popupID) != nil else { return }
            do {
                let closingPopupIDs = try surfaces.beginClientRequestedPopupCascade(popupID)
                for closingPopupID in closingPopupIDs {
                    surfaces.popup(closingPopupID)?.closeOnOwnerThread()
                }
                assertSurfaceStoreInvariants()
            } catch {
                markSurfaceStoreInvariantFailed(error)
            }
        }
    }

    package func popupEventCallbacks(
        popupID: PopupID,
        parentWindowID: WindowID
    ) -> PopupEventCallbacks {
        PopupEventCallbacks(
            onDismissed: { [weak core = self] in
                core?.handlePopupDismissed(popupID, parentWindowID: parentWindowID)
            },
            onClosed: { [weak core = self] in
                core?.handlePopupClosed(popupID)
            },
            onRedrawRequested: { [weak core = self] in
                core?.publishPopupRedrawRequested(
                    popupID: popupID,
                    parentWindowID: parentWindowID
                )
            }
        )
    }

    private func handlePopupDismissed(_ popupID: PopupID, parentWindowID: WindowID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        do {
            guard let dismissal = try surfaces.beginCompositorPopupDismissal(popupID) else {
                eventHub.publish(
                    .popupDismissed(
                        PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                    )
                )
                return
            }

            publishPopupDismissedEvents(dismissal.events)
            for dismissedPopupID in dismissal.popupIDs where dismissedPopupID != popupID {
                surfaces.popup(dismissedPopupID)?.closeOnOwnerThread()
            }
            assertSurfaceStoreInvariants()
        } catch {
            markSurfaceStoreInvariantFailed(error)
        }
    }

    private func handlePopupClosed(_ popupID: PopupID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        let parentWindowID = surfaces.markPopupClosed(popupID)
        if let parentWindowID {
            eventHub.publish(
                .popupClosed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
        }
        assertSurfaceStoreInvariants()
    }

    private func publishPopupRedrawRequested(popupID: PopupID, parentWindowID: WindowID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        eventHub.publish(
            .popupRedrawRequested(
                PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
            )
        )
    }

    func popupIDsTopDown(parentedBy windowID: WindowID) -> [PopupID] {
        surfaces.popupIDsTopDown(parentedBy: windowID)
    }

    private func publishPopupDismissedEvents(_ events: [PopupLifecycleEvent]) {
        for event in events {
            eventHub.publish(.popupDismissed(event))
        }
    }

    private func requireWindowSurfaceID(_ windowID: WindowID) throws -> SurfaceID {
        guard let surfaceID = surfaces.windowSurfaceID(windowID) else {
            throw ClientError.display(.unknownWindow(windowID))
        }

        return surfaceID
    }

    func markSurfaceStoreInvariantFailed(_ error: any Error) {
        markDefunctForFatalFailure(
            .internalInvariantViolation(
                .message("surface store invariant failed: \(String(describing: error))")
            )
        )
    }
}
