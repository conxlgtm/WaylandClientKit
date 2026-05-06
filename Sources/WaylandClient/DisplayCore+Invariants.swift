package enum DisplayCoreRegistryInvariantViolation:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case windowSurfaceKeysDoNotMatchWindows
    case popupSurfaceKeysDoNotMatchPopups
    case popupParentKeysDoNotMatchPopups
    case closedPopupStillHasLiveRecord(PopupID)
    case missingWindowGraphNode(WindowID)
    case missingPopupGraphNode(PopupID)
    case unexpectedGraphWindowNode(SurfaceID)
    case unexpectedGraphPopupNode(SurfaceID)
    case popupParentWindowMismatch(PopupID)
    case popupHandleIndexMismatch(PopupID)

    package var description: String {
        switch self {
        case .windowSurfaceKeysDoNotMatchWindows:
            "window surface keys do not match windows"
        case .popupSurfaceKeysDoNotMatchPopups:
            "popup surface keys do not match popups"
        case .popupParentKeysDoNotMatchPopups:
            "popup parent keys do not match popups"
        case .closedPopupStillHasLiveRecord(let popupID):
            "closed popup \(popupID) still has a live record"
        case .missingWindowGraphNode(let windowID):
            "window \(windowID) is missing from the surface graph"
        case .missingPopupGraphNode(let popupID):
            "popup \(popupID) is missing from the surface graph"
        case .unexpectedGraphWindowNode(let surfaceID):
            "surface graph has unexpected window surface \(surfaceID)"
        case .unexpectedGraphPopupNode(let surfaceID):
            "surface graph has unexpected popup surface \(surfaceID)"
        case .popupParentWindowMismatch(let popupID):
            "popup \(popupID) parent window does not match the graph"
        case .popupHandleIndexMismatch(let popupID):
            "popup \(popupID) handle index does not match the graph"
        }
    }
}

extension DisplayCore {
    package func checkInvariantsForTesting() throws {
        try checkRegistryInvariants()
    }

    func assertRegistryInvariants() {
        #if DEBUG
            do {
                try checkRegistryInvariants()
            } catch {
                preconditionFailure("DisplayCore registry invariant failed: \(error)")
            }
        #endif
    }

    func checkRegistryInvariants() throws {
        try checkRegistryKeySets()
        try checkClosedPopupsHaveNoLiveRecords()
        try checkWindowGraphRecords()
        try checkPopupGraphRecords()
        try checkGraphNodesHaveObjectRecords()
    }

    private func checkRegistryKeySets() throws {
        guard Set(windowSurfaceIDs.keys) == windowIDsForRegistryInvariants else {
            throw DisplayCoreRegistryInvariantViolation.windowSurfaceKeysDoNotMatchWindows
        }
        guard Set(popupSurfaceIDs.keys) == Set(popups.keys) else {
            throw DisplayCoreRegistryInvariantViolation.popupSurfaceKeysDoNotMatchPopups
        }
        guard Set(popupParentWindowIDs.keys) == Set(popups.keys) else {
            throw DisplayCoreRegistryInvariantViolation.popupParentKeysDoNotMatchPopups
        }
    }

    private func checkClosedPopupsHaveNoLiveRecords() throws {
        for closedPopupID in closedPopupIDs
        where popups[closedPopupID] != nil
            || popupSurfaceIDs[closedPopupID] != nil
            || popupParentWindowIDs[closedPopupID] != nil
        {
            throw DisplayCoreRegistryInvariantViolation.closedPopupStillHasLiveRecord(
                closedPopupID
            )
        }
    }

    private func checkWindowGraphRecords() throws {
        for (windowID, surfaceID) in windowSurfaceIDs {
            guard
                let node = surfaceGraph.nodes[surfaceID],
                node.role == .toplevel(windowID: windowID)
            else {
                throw DisplayCoreRegistryInvariantViolation.missingWindowGraphNode(windowID)
            }
        }
    }

    private func checkPopupGraphRecords() throws {
        for (popupID, surfaceID) in popupSurfaceIDs {
            guard
                let node = surfaceGraph.nodes[surfaceID],
                case .popup(let graphPopupID, _) = node.role,
                graphPopupID == popupID
            else {
                throw DisplayCoreRegistryInvariantViolation.missingPopupGraphNode(popupID)
            }
            guard node.windowID == popupParentWindowIDs[popupID] else {
                throw DisplayCoreRegistryInvariantViolation.popupParentWindowMismatch(popupID)
            }
            guard surfaceGraph.livePopupSurfacesByID[popupID] == surfaceID else {
                throw DisplayCoreRegistryInvariantViolation.popupHandleIndexMismatch(popupID)
            }
        }
    }

    private func checkGraphNodesHaveObjectRecords() throws {
        let knownWindowSurfaces = Set(windowSurfaceIDs.values)
        let knownPopupSurfaces = Set(popupSurfaceIDs.values)
        for (surfaceID, node) in surfaceGraph.nodes {
            switch node.role {
            case .toplevel:
                guard knownWindowSurfaces.contains(surfaceID) else {
                    throw
                        DisplayCoreRegistryInvariantViolation
                        .unexpectedGraphWindowNode(surfaceID)
                }
            case .popup:
                guard knownPopupSurfaces.contains(surfaceID) else {
                    throw
                        DisplayCoreRegistryInvariantViolation
                        .unexpectedGraphPopupNode(surfaceID)
                }
            }
        }
    }
}
