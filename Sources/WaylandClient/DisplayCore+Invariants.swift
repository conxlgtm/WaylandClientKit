package enum DisplayCoreRegistryInvariantViolation:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case closedPopupStillHasLiveRecord(PopupID)
    case missingWindowGraphNode(WindowID)
    case missingPopupGraphNode(PopupID)
    case unexpectedGraphWindowNode(SurfaceID)
    case unexpectedGraphPopupNode(SurfaceID)
    case popupParentWindowMismatch(PopupID)
    case popupHandleIndexMismatch(PopupID)

    package var description: String {
        switch self {
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

    static func checkRegistryInvariantsForTesting(
        surfaceIndex: DisplaySurfaceIndex,
        surfaceGraph: SurfaceGraph
    ) throws {
        try checkRegistryInvariants(
            surfaceIndex: surfaceIndex,
            surfaceGraph: surfaceGraph
        )
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
        try Self.checkRegistryInvariants(
            surfaceIndex: registry.surfaceIndex,
            surfaceGraph: surfaceGraph
        )
    }

    private static func checkRegistryInvariants(
        surfaceIndex: DisplaySurfaceIndex,
        surfaceGraph: SurfaceGraph
    ) throws {
        try checkClosedPopupsHaveNoLiveRecords(surfaceIndex: surfaceIndex)
        try checkWindowGraphRecords(
            surfaceIndex: surfaceIndex,
            surfaceGraph: surfaceGraph
        )
        try checkPopupGraphRecords(
            surfaceIndex: surfaceIndex,
            surfaceGraph: surfaceGraph
        )
        try checkGraphNodesHaveIndexRecords(
            surfaceIndex: surfaceIndex,
            surfaceGraph: surfaceGraph
        )
    }

    private static func checkClosedPopupsHaveNoLiveRecords(
        surfaceIndex: DisplaySurfaceIndex
    ) throws {
        for closedPopupID in surfaceIndex.closedPopupIDs
        where surfaceIndex.popupIDs.contains(closedPopupID) {
            throw DisplayCoreRegistryInvariantViolation.closedPopupStillHasLiveRecord(
                closedPopupID
            )
        }
    }

    private static func checkWindowGraphRecords(
        surfaceIndex: DisplaySurfaceIndex,
        surfaceGraph: SurfaceGraph
    ) throws {
        for (windowID, surfaceID) in surfaceIndex.windowSurfaceIDs {
            guard
                let node = surfaceGraph.nodes[surfaceID],
                node.role == .toplevel(windowID: windowID)
            else {
                throw DisplayCoreRegistryInvariantViolation.missingWindowGraphNode(windowID)
            }
        }
    }

    private static func checkPopupGraphRecords(
        surfaceIndex: DisplaySurfaceIndex,
        surfaceGraph: SurfaceGraph
    ) throws {
        for (popupID, surfaceID) in surfaceIndex.popupSurfaceIDs {
            guard
                let node = surfaceGraph.nodes[surfaceID],
                case .popup(let graphPopupID, _) = node.role,
                graphPopupID == popupID
            else {
                throw DisplayCoreRegistryInvariantViolation.missingPopupGraphNode(popupID)
            }
            guard node.windowID == surfaceIndex.popupParentWindowIDs[popupID] else {
                throw DisplayCoreRegistryInvariantViolation.popupParentWindowMismatch(popupID)
            }
            guard surfaceGraph.livePopupSurfacesByID[popupID] == surfaceID else {
                throw DisplayCoreRegistryInvariantViolation.popupHandleIndexMismatch(popupID)
            }
        }
    }

    private static func checkGraphNodesHaveIndexRecords(
        surfaceIndex: DisplaySurfaceIndex,
        surfaceGraph: SurfaceGraph
    ) throws {
        let knownWindowSurfaces = Set(surfaceIndex.windowSurfaceIDs.values)
        let knownPopupSurfaces = Set(surfaceIndex.popupSurfaceIDs.values)
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
