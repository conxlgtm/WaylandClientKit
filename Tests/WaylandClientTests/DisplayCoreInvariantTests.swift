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
    func registryWindowRecordWithoutGraphFailsInvariant() throws {
        var surfaceIndex = DisplaySurfaceIndex()
        let surfaceGraph = SurfaceGraph()
        let windowID = WindowID(rawValue: 3)

        surfaceIndex.insertWindow(windowID: windowID, surfaceID: SurfaceID(rawValue: 30))

        #expect(
            throws:
                DisplayCoreRegistryInvariantViolation
                .missingWindowGraphNode(windowID)
        ) {
            try DisplayCore.checkRegistryInvariantsForTesting(
                surfaceIndex: surfaceIndex,
                surfaceGraph: surfaceGraph
            )
        }
    }

    @Test
    func registryPopupRecordWithoutGraphFailsInvariant() throws {
        var surfaceIndex = DisplaySurfaceIndex()
        let surfaceGraph = SurfaceGraph()
        let popupID = PopupID(rawValue: 5)

        surfaceIndex.insertPopup(
            popupID: popupID,
            surfaceID: SurfaceID(rawValue: 31),
            parentWindowID: WindowID(rawValue: 3)
        )

        #expect(
            throws:
                DisplayCoreRegistryInvariantViolation
                .missingPopupGraphNode(popupID)
        ) {
            try DisplayCore.checkRegistryInvariantsForTesting(
                surfaceIndex: surfaceIndex,
                surfaceGraph: surfaceGraph
            )
        }
    }

    @Test
    func popupClosedTransitionMarksClosedAndRemovesLiveIndexRecord() throws {
        var fixture = try PopupIndexFixture.make()

        _ = try fixture.surfaceGraph.destroyClientRequestedPopupCascade(
            fixture.popupSurfaceID
        )
        fixture.surfaceIndex.beginPopupRegistryRemoval(for: [fixture.popupID])

        #expect(fixture.surfaceIndex.markPopupClosed(fixture.popupID) == fixture.windowID)
        fixture.surfaceIndex.finishPopupRegistryRemoval(for: fixture.popupID)

        #expect(fixture.surfaceIndex.closedPopupIDs == Set([fixture.popupID]))
        #expect(fixture.surfaceIndex.popupIDs.isEmpty)
        #expect(fixture.surfaceIndex.pendingPopupRegistryRemovalIDs.isEmpty)
        try DisplayCore.checkRegistryInvariantsForTesting(
            surfaceIndex: fixture.surfaceIndex,
            surfaceGraph: fixture.surfaceGraph
        )
    }

    @Test
    func popupCascadeClosureDefersInvariantUntilLastClosedRecord() throws {
        var fixture = try PopupCascadeIndexFixture.make()

        _ = try fixture.surfaceGraph.destroyClientRequestedPopupCascade(
            fixture.firstPopupSurfaceID
        )
        fixture.surfaceIndex.beginPopupRegistryRemoval(
            for: [fixture.secondPopupID, fixture.firstPopupID]
        )

        #expect(
            fixture.surfaceIndex.markPopupClosed(fixture.secondPopupID)
                == fixture.windowID
        )
        fixture.surfaceIndex.finishPopupRegistryRemoval(for: fixture.secondPopupID)

        #expect(
            fixture.surfaceIndex.pendingPopupRegistryRemovalIDs
                == Set([fixture.firstPopupID])
        )
        #expect(fixture.surfaceIndex.popupIDs == Set([fixture.firstPopupID]))
        #expect(
            throws:
                DisplayCoreRegistryInvariantViolation
                .missingPopupGraphNode(fixture.firstPopupID)
        ) {
            try DisplayCore.checkRegistryInvariantsForTesting(
                surfaceIndex: fixture.surfaceIndex,
                surfaceGraph: fixture.surfaceGraph
            )
        }

        #expect(
            fixture.surfaceIndex.markPopupClosed(fixture.firstPopupID)
                == fixture.windowID
        )
        fixture.surfaceIndex.finishPopupRegistryRemoval(for: fixture.firstPopupID)

        #expect(
            fixture.surfaceIndex.closedPopupIDs
                == Set([fixture.firstPopupID, fixture.secondPopupID])
        )
        #expect(fixture.surfaceIndex.popupIDs.isEmpty)
        #expect(fixture.surfaceIndex.pendingPopupRegistryRemovalIDs.isEmpty)
        try DisplayCore.checkRegistryInvariantsForTesting(
            surfaceIndex: fixture.surfaceIndex,
            surfaceGraph: fixture.surfaceGraph
        )
    }
}

private struct PopupIndexFixture {
    var surfaceIndex: DisplaySurfaceIndex
    var surfaceGraph: SurfaceGraph
    let windowID: WindowID
    let popupID: PopupID
    let popupSurfaceID: SurfaceID

    static func make() throws -> PopupIndexFixture {
        try make(
            windowID: WindowID(rawValue: 3),
            popupID: PopupID(rawValue: 5),
            windowSurfaceID: SurfaceID(rawValue: 30),
            popupSurfaceID: SurfaceID(rawValue: 31)
        )
    }

    static func make(
        windowID: WindowID,
        popupID: PopupID,
        windowSurfaceID: SurfaceID,
        popupSurfaceID: SurfaceID
    ) throws -> PopupIndexFixture {
        var surfaceIndex = DisplaySurfaceIndex()
        var surfaceGraph = SurfaceGraph()

        try surfaceGraph.registerTopLevel(
            surfaceID: windowSurfaceID,
            windowID: windowID
        )
        surfaceIndex.insertWindow(windowID: windowID, surfaceID: windowSurfaceID)
        try surfaceGraph.registerPopup(
            surfaceID: popupSurfaceID,
            popupID: popupID,
            parent: windowSurfaceID
        )
        surfaceIndex.insertPopup(
            popupID: popupID,
            surfaceID: popupSurfaceID,
            parentWindowID: windowID
        )

        return PopupIndexFixture(
            surfaceIndex: surfaceIndex,
            surfaceGraph: surfaceGraph,
            windowID: windowID,
            popupID: popupID,
            popupSurfaceID: popupSurfaceID
        )
    }
}

private struct PopupCascadeIndexFixture {
    var surfaceIndex: DisplaySurfaceIndex
    var surfaceGraph: SurfaceGraph
    let windowID: WindowID
    let firstPopupID: PopupID
    let secondPopupID: PopupID
    let firstPopupSurfaceID: SurfaceID

    static func make() throws -> PopupCascadeIndexFixture {
        let windowID = WindowID(rawValue: 3)
        let windowSurfaceID = SurfaceID(rawValue: 30)
        let firstPopupID = PopupID(rawValue: 5)
        let secondPopupID = PopupID(rawValue: 6)
        let firstPopupSurfaceID = SurfaceID(rawValue: 31)
        let secondPopupSurfaceID = SurfaceID(rawValue: 32)
        var fixture = try PopupIndexFixture.make(
            windowID: windowID,
            popupID: firstPopupID,
            windowSurfaceID: windowSurfaceID,
            popupSurfaceID: firstPopupSurfaceID
        )

        try fixture.surfaceGraph.registerPopup(
            surfaceID: secondPopupSurfaceID,
            popupID: secondPopupID,
            parent: firstPopupSurfaceID
        )
        fixture.surfaceIndex.insertPopup(
            popupID: secondPopupID,
            surfaceID: secondPopupSurfaceID,
            parentWindowID: windowID
        )

        return PopupCascadeIndexFixture(
            surfaceIndex: fixture.surfaceIndex,
            surfaceGraph: fixture.surfaceGraph,
            windowID: windowID,
            firstPopupID: firstPopupID,
            secondPopupID: secondPopupID,
            firstPopupSurfaceID: firstPopupSurfaceID
        )
    }
}
