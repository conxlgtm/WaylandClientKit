package protocol PopupRoleSurfaceEventCallbacks: AnyObject {
    var id: PopupID { get }
    var parentWindowID: WindowID { get }
    var onDismissed: (() -> Void)? { get set }
    var onClosed: (() -> Void)? { get set }
    var onRedrawRequested: (() -> Void)? { get set }
}

extension PopupRoleSurface: PopupRoleSurfaceEventCallbacks {}

extension DisplayCore {
    func createPopup(
        parent windowID: WindowID,
        configuration popupConfiguration: PopupConfiguration
    ) throws -> PopupID {
        try withFatalFailureFinalization {
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
            popups[popup.id] = popup
            popupSurfaceIDs[popup.id] = popupSurfaceID
            popupParentWindowIDs[popup.id] = windowID
            closedPopupIDs.remove(popup.id)
            installPopupEventCallbacks(for: popup)
            return popup.id
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
            guard !isClosed, let session else { return }
            publishInputEvents(session.drainInputEventsOnOwnerThread())
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
            if closedPopupIDs.contains(popupID) {
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
            guard !needsFatalFailureFinalization else { return }
            guard !closedPopupIDs.contains(popupID) else { return }
            guard popups[popupID] != nil else { return }
            do {
                let popupSurfaceID = try requirePopupSurfaceID(popupID)
                let nodes = try surfaceGraph.destroyClientRequestedPopupCascade(popupSurfaceID)
                for closingPopupID in popupIDs(from: nodes) {
                    popups[closingPopupID]?.closeOnOwnerThread()
                }
            } catch {
                markSurfaceGraphInvariantFailed(error)
            }
        }
    }

    package func installPopupEventCallbacks(for popup: any PopupRoleSurfaceEventCallbacks) {
        let popupID = popup.id
        let parentWindowID = popup.parentWindowID
        popup.onDismissed = { [weak core = self] in
            core?.handlePopupDismissed(popupID, parentWindowID: parentWindowID)
        }
        popup.onClosed = { [weak core = self] in
            core?.handlePopupClosed(popupID)
        }
        popup.onRedrawRequested = { [weak core = self] in
            core?.eventHub.publish(
                .popupRedrawRequested(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
        }
    }

    private func handlePopupDismissed(_ popupID: PopupID, parentWindowID: WindowID) {
        guard let surfaceID = popupSurfaceIDs[popupID] else {
            eventHub.publish(
                .popupDismissed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
            return
        }

        do {
            let dismissedNodes = try surfaceGraph.dismissPopupFromCompositor(surfaceID)
            publishPopupDismissedEvents(for: dismissedNodes)
            for dismissedPopupID in popupIDs(from: dismissedNodes)
            where dismissedPopupID != popupID {
                popups[dismissedPopupID]?.closeOnOwnerThread()
            }
        } catch {
            markSurfaceGraphInvariantFailed(error)
            return
        }
    }

    private func handlePopupClosed(_ popupID: PopupID) {
        let parentWindowID = popupParentWindowIDs[popupID] ?? popups[popupID]?.parentWindowID
        closedPopupIDs.insert(popupID)
        popups.removeValue(forKey: popupID)
        popupSurfaceIDs.removeValue(forKey: popupID)
        popupParentWindowIDs.removeValue(forKey: popupID)
        if let parentWindowID {
            eventHub.publish(
                .popupClosed(
                    PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
                )
            )
        }
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
        guard let surfaceID = windowSurfaceIDs[windowID] else {
            throw ClientError.display(.unknownWindow(windowID))
        }

        return surfaceID
    }

    private func requirePopupSurfaceID(_ popupID: PopupID) throws -> SurfaceID {
        guard !closedPopupIDs.contains(popupID) else {
            throw ClientError.display(.closedPopup)
        }
        guard let surfaceID = popupSurfaceIDs[popupID] else {
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
