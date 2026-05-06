import Testing

@testable import WaylandClient

@Suite
struct DisplayCoreInvariantTests {
    @Test
    func emptyRegistrySatisfiesInvariants() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())

        try core.checkInvariantsForTesting()
    }

    @Test
    func windowSurfaceWithoutWindowFailsInvariant() {
        let core = DisplayCore(eventHub: DisplayEventHub())

        core.windowSurfaceIDs[WindowID(rawValue: 1)] = SurfaceID(rawValue: 10)

        #expect(
            throws: DisplayCoreRegistryInvariantViolation
                .windowSurfaceKeysDoNotMatchWindows
        ) {
            try core.checkInvariantsForTesting()
        }
    }

    @Test
    func popupSurfaceWithoutPopupFailsInvariant() {
        let core = DisplayCore(eventHub: DisplayEventHub())

        core.popupSurfaceIDs[PopupID(rawValue: 2)] = SurfaceID(rawValue: 20)

        #expect(
            throws: DisplayCoreRegistryInvariantViolation
                .popupSurfaceKeysDoNotMatchPopups
        ) {
            try core.checkInvariantsForTesting()
        }
    }

    @Test
    func graphWindowWithoutRegistryFailsInvariant() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let surfaceID = SurfaceID(rawValue: 30)

        try core.surfaceGraph.registerTopLevel(
            surfaceID: surfaceID,
            windowID: WindowID(rawValue: 3)
        )

        #expect(
            throws:
                DisplayCoreRegistryInvariantViolation
                .unexpectedGraphWindowNode(surfaceID)
        ) {
            try core.checkInvariantsForTesting()
        }
    }

    @Test
    func popupCascadeClosureDefersRegistryInvariantUntilLastCallback() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let parentWindowID = WindowID(rawValue: 4)
        let firstPopupID = PopupID(rawValue: 5)
        let secondPopupID = PopupID(rawValue: 6)
        let firstPopup = PopupInvariantCallbackProbe(
            id: firstPopupID,
            parentWindowID: parentWindowID
        )
        let secondPopup = PopupInvariantCallbackProbe(
            id: secondPopupID,
            parentWindowID: parentWindowID
        )

        core.popupSurfaceIDs[firstPopupID] = SurfaceID(rawValue: 50)
        core.popupSurfaceIDs[secondPopupID] = SurfaceID(rawValue: 60)
        core.popupParentWindowIDs[firstPopupID] = parentWindowID
        core.popupParentWindowIDs[secondPopupID] = parentWindowID
        core.beginPopupRegistryRemovalForTesting([firstPopupID, secondPopupID])
        core.installPopupEventCallbacks(for: firstPopup)
        core.installPopupEventCallbacks(for: secondPopup)

        let firstClosed = try #require(firstPopup.onClosed)
        firstClosed()

        #expect(core.pendingPopupRegistryRemovalIDsForTesting == Set([secondPopupID]))
        #expect(core.closedPopupIDs.contains(firstPopupID))
        #expect(core.popupSurfaceIDs[secondPopupID] != nil)

        let secondClosed = try #require(secondPopup.onClosed)
        secondClosed()

        #expect(core.pendingPopupRegistryRemovalIDsForTesting.isEmpty)
        try core.checkInvariantsForTesting()
    }
}

private final class PopupInvariantCallbackProbe: PopupRoleSurfaceEventCallbacks {
    let id: PopupID
    let parentWindowID: WindowID
    var onDismissed: (() -> Void)?
    var onClosed: (() -> Void)?
    var onRedrawRequested: (() -> Void)?

    init(id popupID: PopupID, parentWindowID popupParentWindowID: WindowID) {
        id = popupID
        parentWindowID = popupParentWindowID
    }
}
