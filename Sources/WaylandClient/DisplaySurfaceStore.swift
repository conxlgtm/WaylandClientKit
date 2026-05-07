package enum DisplaySurfaceStoreError: Error, Equatable, Sendable {
    case duplicateWindow(WindowID)
    case duplicateSurface(SurfaceID)
    case duplicatePopup(PopupID)
    case unknownPopup(PopupID)
    case unknownSurface(SurfaceID)
    case unknownParent(SurfaceID)
    case nonTopmostPopupDestroy(requested: SurfaceID, topmost: SurfaceID?)
    case toplevelDestroyedWithLivePopups(WindowID)
}

package enum DisplaySurfaceStoreInvariantViolation:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case closedPopupStillHasRecord(PopupID)
    case liveWindowMissingTopology(WindowID)
    case livePopupMissingTopology(PopupID)
    case closingPopupStillHasLiveTopology(PopupID)
    case topologyWindowMissingRecord(SurfaceID)
    case topologyPopupMissingRecord(SurfaceID)
    case popupParentWindowMismatch(PopupID)
    case popupHandleIndexMismatch(PopupID)

    package var description: String {
        switch self {
        case .closedPopupStillHasRecord(let popupID):
            "closed popup \(popupID) still has a surface record"
        case .liveWindowMissingTopology(let windowID):
            "window \(windowID) is missing from the surface topology"
        case .livePopupMissingTopology(let popupID):
            "popup \(popupID) is missing from the surface topology"
        case .closingPopupStillHasLiveTopology(let popupID):
            "closing popup \(popupID) still has a live topology node"
        case .topologyWindowMissingRecord(let surfaceID):
            "surface topology has unexpected window surface \(surfaceID)"
        case .topologyPopupMissingRecord(let surfaceID):
            "surface topology has unexpected popup surface \(surfaceID)"
        case .popupParentWindowMismatch(let popupID):
            "popup \(popupID) parent window does not match the topology"
        case .popupHandleIndexMismatch(let popupID):
            "popup \(popupID) handle index does not match the topology"
        }
    }
}

package struct DisplayWindowRecord<WindowReference> {
    package let window: WindowReference
    package let surfaceID: SurfaceID
}

package enum DisplayPopupLifecycle: Equatable, Sendable {
    case live
    case closing
}

package protocol DisplayWindowReference {
    var displayWindowID: WindowID { get }
}

package protocol DisplayPopupReference {
    var displayPopupID: PopupID { get }
}

package struct DisplayPopupRecord<PopupReference> {
    package let popup: PopupReference
    package let surfaceID: SurfaceID
    package let parentWindowID: WindowID
    package var lifecycle: DisplayPopupLifecycle
}

package struct DisplayPopupDismissal {
    package let popupIDs: [PopupID]
    package let events: [PopupLifecycleEvent]
}

package struct DisplaySurfaceStore<
    WindowReference: DisplayWindowReference,
    PopupReference: DisplayPopupReference
> {
    private var windowRecords: [WindowID: DisplayWindowRecord<WindowReference>] = [:]
    private var popupRecords: [PopupID: DisplayPopupRecord<PopupReference>] = [:]
    private var closedPopupIDsStorage: Set<PopupID> = []
    private var topology = SurfaceGraph()

    package init() {
        // Starts with no registered role surfaces.
    }

    package var allWindowIDs: [WindowID] {
        Array(windowRecords.keys)
    }

    package func window(_ windowID: WindowID) -> WindowReference? {
        windowRecords[windowID]?.window
    }

    package func popup(_ popupID: PopupID) -> PopupReference? {
        popupRecords[popupID]?.popup
    }

    package func windowSurfaceID(_ windowID: WindowID) -> SurfaceID? {
        windowRecords[windowID]?.surfaceID
    }

    package func popupIsClosing(_ popupID: PopupID) -> Bool {
        popupRecords[popupID]?.lifecycle == .closing
    }

    package func popupIsClosedOrClosing(_ popupID: PopupID) -> Bool {
        closedPopupIDsStorage.contains(popupID) || popupIsClosing(popupID)
    }

    package func popupIDsTopDown(parentedBy windowID: WindowID) -> [PopupID] {
        topology.popupIDsTopDown(parentedBy: windowID)
    }

    package func windowID(for surfaceID: SurfaceID) throws -> WindowID {
        try topology.windowID(for: surfaceID)
    }

    package mutating func insertWindow(
        _ window: WindowReference,
        surfaceID: SurfaceID
    ) throws {
        let windowID = window.displayWindowID
        guard windowRecords[windowID] == nil else {
            throw DisplaySurfaceStoreError.duplicateWindow(windowID)
        }
        try topology.registerTopLevel(surfaceID: surfaceID, windowID: windowID)
        windowRecords[windowID] = DisplayWindowRecord(
            window: window,
            surfaceID: surfaceID
        )
    }

    package mutating func removeWindow(_ windowID: WindowID) throws {
        guard let record = windowRecords[windowID] else { return }

        try topology.unregisterTopLevel(record.surfaceID)
        windowRecords.removeValue(forKey: windowID)
    }

    @discardableResult
    package mutating func insertPopup(
        _ popup: PopupReference,
        surfaceID: SurfaceID,
        parent parentSurfaceID: SurfaceID
    ) throws -> WindowID {
        let popupID = popup.displayPopupID
        guard popupRecords[popupID] == nil else {
            throw DisplaySurfaceStoreError.duplicatePopup(popupID)
        }
        let parentWindowID = try topology.registerPopup(
            surfaceID: surfaceID,
            popupID: popupID,
            parent: parentSurfaceID
        )
        popupRecords[popupID] = DisplayPopupRecord(
            popup: popup,
            surfaceID: surfaceID,
            parentWindowID: parentWindowID,
            lifecycle: .live
        )
        closedPopupIDsStorage.remove(popupID)
        return parentWindowID
    }

    @discardableResult
    package mutating func beginClientRequestedPopupCascade(
        _ popupID: PopupID
    ) throws -> [PopupID] {
        guard let record = popupRecords[popupID] else {
            throw DisplaySurfaceStoreError.unknownPopup(popupID)
        }
        guard record.lifecycle == .live else { return [] }

        let removedNodes = try topology.destroyClientRequestedPopupCascade(record.surfaceID)
        let popupIDs = removedNodes.compactMap(\.popupID)
        markPopupsClosing(popupIDs)
        return popupIDs
    }

    package mutating func beginCompositorPopupDismissal(
        _ popupID: PopupID
    ) throws -> DisplayPopupDismissal? {
        guard let record = popupRecords[popupID], record.lifecycle == .live else {
            return nil
        }

        let dismissedNodes = try topology.dismissPopupFromCompositor(record.surfaceID)
        let dismissedPopupIDs = dismissedNodes.compactMap(\.popupID)
        markPopupsClosing(dismissedPopupIDs)
        let events = dismissedNodes.compactMap { node in
            node.popupID.map { popupID in
                PopupLifecycleEvent(popup: popupID, parentWindowID: node.windowID)
            }
        }
        return DisplayPopupDismissal(popupIDs: dismissedPopupIDs, events: events)
    }

    @discardableResult
    package mutating func markPopupClosed(_ popupID: PopupID) -> WindowID? {
        let parentWindowID = popupRecords[popupID]?.parentWindowID
        popupRecords.removeValue(forKey: popupID)
        closedPopupIDsStorage.insert(popupID)
        return parentWindowID
    }

    package mutating func removeAll() {
        windowRecords.removeAll(keepingCapacity: false)
        popupRecords.removeAll(keepingCapacity: false)
        closedPopupIDsStorage.removeAll(keepingCapacity: false)
        topology = SurfaceGraph()
    }

    package func checkInvariantsForTesting() throws {
        try checkInvariants()
    }

    package func checkInvariants() throws {
        try checkClosedPopupsHaveNoRecords()
        try checkWindowTopologyRecords()
        try checkPopupTopologyRecords()
        try checkTopologyNodesHaveRecords()
    }

    private mutating func markPopupsClosing(_ popupIDs: [PopupID]) {
        for popupID in popupIDs {
            popupRecords[popupID]?.lifecycle = .closing
        }
    }

    private func checkClosedPopupsHaveNoRecords() throws {
        for popupID in closedPopupIDsStorage where popupRecords[popupID] != nil {
            throw DisplaySurfaceStoreInvariantViolation.closedPopupStillHasRecord(popupID)
        }
    }

    private func checkWindowTopologyRecords() throws {
        for (windowID, record) in windowRecords {
            guard topology.windowNodeMatches(surfaceID: record.surfaceID, windowID: windowID) else {
                throw DisplaySurfaceStoreInvariantViolation.liveWindowMissingTopology(windowID)
            }
        }
    }

    private func checkPopupTopologyRecords() throws {
        for (popupID, record) in popupRecords {
            switch record.lifecycle {
            case .live:
                if let node = topology.nodes[record.surfaceID],
                    case .popup(let nodePopupID, _) = node.role,
                    nodePopupID == popupID,
                    node.windowID != record.parentWindowID
                {
                    throw
                        DisplaySurfaceStoreInvariantViolation
                        .popupParentWindowMismatch(popupID)
                }
                guard
                    topology.popupNodeMatches(
                        surfaceID: record.surfaceID,
                        popupID: popupID,
                        parentWindowID: record.parentWindowID
                    )
                else {
                    throw DisplaySurfaceStoreInvariantViolation.livePopupMissingTopology(popupID)
                }
                guard topology.livePopupSurfaceID(for: popupID) == record.surfaceID else {
                    throw DisplaySurfaceStoreInvariantViolation.popupHandleIndexMismatch(popupID)
                }
            case .closing:
                guard !topology.contains(record.surfaceID) else {
                    throw
                        DisplaySurfaceStoreInvariantViolation
                        .closingPopupStillHasLiveTopology(popupID)
                }
            }
        }
    }

    private func checkTopologyNodesHaveRecords() throws {
        for (surfaceID, node) in topology.nodes {
            switch node.role {
            case .toplevel(let windowID):
                guard windowRecords[windowID]?.surfaceID == surfaceID else {
                    throw
                        DisplaySurfaceStoreInvariantViolation
                        .topologyWindowMissingRecord(surfaceID)
                }
            case .popup(let popupID, _):
                guard
                    let record = popupRecords[popupID],
                    record.lifecycle == .live,
                    record.surfaceID == surfaceID
                else {
                    throw
                        DisplaySurfaceStoreInvariantViolation
                        .topologyPopupMissingRecord(surfaceID)
                }
            }
        }
    }
}

extension TopLevelWindow: DisplayWindowReference {
    package var displayWindowID: WindowID {
        id
    }
}

extension PopupRoleSurface: DisplayPopupReference {
    package var displayPopupID: PopupID {
        id
    }
}
