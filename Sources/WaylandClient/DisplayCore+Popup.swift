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
        try registerPopup(popup, surfaceParent: parentSurfaceID, windowID: windowID)
        return popup.id
    }

    private func registerPopup(
        _ popup: PopupRoleSurface,
        surfaceParent parentSurfaceID: SurfaceID,
        windowID: WindowID
    ) throws {
        let popupSurfaceID = SurfaceID(rawObjectID: popup.surfaceID)
        do {
            try surfaceGraph.registerPopup(
                surfaceID: popupSurfaceID,
                popupID: popup.id,
                parent: parentSurfaceID
            )
        } catch {
            popup.closeOnOwnerThread()
            throw error
        }
        registry.insertPopup(popup, surfaceID: popupSurfaceID, parentWindowID: windowID)
        installPopupEventCallbacks(for: popup, parentWindowID: windowID)
        assertRegistryInvariants()
    }

    private func installPopupEventCallbacks(
        for popup: PopupRoleSurface,
        parentWindowID: WindowID
    ) {
        let callbacks = popupEventCallbacks(popupID: popup.id, parentWindowID: parentWindowID)
        popup.onDismissed = callbacks.onDismissed
        popup.onClosed = callbacks.onClosed
        popup.onRedrawRequested = callbacks.onRedrawRequested
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

    func popupIsClosed(_ popupID: PopupID) throws -> Bool {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            if registry.closedPopupIDs.contains(popupID) {
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
            guard !registry.closedPopupIDs.contains(popupID) else { return }
            guard registry.popup(popupID) != nil else { return }
            do {
                let popupSurfaceID = try requirePopupSurfaceID(popupID)
                let nodes = try surfaceGraph.destroyClientRequestedPopupCascade(popupSurfaceID)
                let closingPopupIDs = popupIDs(from: nodes)
                beginPopupRegistryRemoval(for: closingPopupIDs)
                for closingPopupID in closingPopupIDs {
                    registry.popup(closingPopupID)?.closeOnOwnerThread()
                }
                assertRegistryInvariantsAfterPopupRemovalIfReady()
            } catch {
                markSurfaceGraphInvariantFailed(error)
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
                core?.eventHub.publish(
                    .popupRedrawRequested(
                        PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                    )
                )
            }
        )
    }

    private func handlePopupDismissed(_ popupID: PopupID, parentWindowID: WindowID) {
        guard let surfaceID = registry.popupSurfaceID(popupID) else {
            eventHub.publish(
                .popupDismissed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
            return
        }

        do {
            let dismissedNodes = try surfaceGraph.dismissPopupFromCompositor(surfaceID)
            let dismissedPopupIDs = popupIDs(from: dismissedNodes)
            beginPopupRegistryRemoval(for: dismissedPopupIDs)
            publishPopupDismissedEvents(for: dismissedNodes)
            for dismissedPopupID in dismissedPopupIDs
            where dismissedPopupID != popupID {
                registry.popup(dismissedPopupID)?.closeOnOwnerThread()
            }
        } catch {
            markSurfaceGraphInvariantFailed(error)
            return
        }
    }

    private func handlePopupClosed(_ popupID: PopupID) {
        let parentWindowID = registry.markPopupClosed(popupID)
        if let parentWindowID {
            eventHub.publish(
                .popupClosed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
        }
        finishPopupRegistryRemoval(for: popupID)
    }

    func popupIDsTopDown(parentedBy windowID: WindowID) -> [PopupID] {
        popupIDs(from: surfaceGraph.popupNodesTopDown(parentedBy: windowID))
    }

    private func popupIDs(from nodes: [SurfaceNode]) -> [PopupID] {
        nodes.compactMap { node in
            popupID(from: node)
        }
    }

    private func popupID(from node: SurfaceNode) -> PopupID? {
        guard case .popup(let popupID, _) = node.role else {
            return nil
        }

        return popupID
    }

    private func publishPopupDismissedEvents(for nodes: [SurfaceNode]) {
        for node in nodes {
            guard case .popup(let popupID, _) = node.role else { continue }
            eventHub.publish(
                .popupDismissed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: node.windowID)
                )
            )
        }
    }

    private func requireWindowSurfaceID(_ windowID: WindowID) throws -> SurfaceID {
        guard let surfaceID = registry.windowSurfaceID(windowID) else {
            throw ClientError.display(.unknownWindow(windowID))
        }

        return surfaceID
    }

    private func requirePopupSurfaceID(_ popupID: PopupID) throws -> SurfaceID {
        guard !registry.closedPopupIDs.contains(popupID) else {
            throw ClientError.display(.closedPopup)
        }
        guard let surfaceID = registry.popupSurfaceID(popupID) else {
            throw ClientError.display(.unknownPopup)
        }

        return surfaceID
    }

    func markSurfaceGraphInvariantFailed(_ error: any Error) {
        markDefunctForFatalFailure(
            .internalInvariantViolation(
                .message("surface graph invariant failed: \(String(describing: error))")
            )
        )
    }
}
