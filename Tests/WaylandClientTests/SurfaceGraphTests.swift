import Testing

@testable import WaylandClient

@Suite
struct SurfaceGraphTests {
    @Test
    func popupRegistrationInheritsRootWindowAndUpdatesParentChildren() throws {
        var graph = SurfaceGraph()
        let windowID = WindowID(rawValue: 1)
        let rootSurface = SurfaceID(rawValue: 10)
        let popupSurface = SurfaceID(rawValue: 11)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: windowID)
        try graph.registerPopup(
            surfaceID: popupSurface,
            popupID: PopupID(rawValue: 100),
            parent: rootSurface
        )

        #expect(try graph.windowID(for: popupSurface) == windowID)
        #expect(graph.nodes[rootSurface]?.children == [popupSurface])
        #expect(graph.popupStacksByRoot[rootSurface]?.topmost == popupSurface)
        #expect(
            graph.nodes[popupSurface]?.role
                == .popup(popupID: PopupID(rawValue: 100), parent: rootSurface)
        )
    }

    @Test
    func clientDestroyRejectsNonTopmostPopup() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 20)
        let firstPopup = SurfaceID(rawValue: 21)
        let secondPopup = SurfaceID(rawValue: 22)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 2))
        try graph.registerPopup(
            surfaceID: firstPopup,
            popupID: PopupID(rawValue: 201),
            parent: rootSurface
        )
        try graph.registerPopup(
            surfaceID: secondPopup,
            popupID: PopupID(rawValue: 202),
            parent: firstPopup
        )

        #expect(
            throws: DisplaySurfaceStoreError.nonTopmostPopupDestroy(
                requested: firstPopup,
                topmost: secondPopup
            )
        ) {
            try graph.destroyClientRequestedPopup(firstPopup)
        }
    }

    @Test
    func clientDestroyAllowsOnlyTopmostPopup() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 30)
        let firstPopup = SurfaceID(rawValue: 31)
        let secondPopup = SurfaceID(rawValue: 32)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 3))
        try graph.registerPopup(
            surfaceID: firstPopup,
            popupID: PopupID(rawValue: 301),
            parent: rootSurface
        )
        try graph.registerPopup(
            surfaceID: secondPopup,
            popupID: PopupID(rawValue: 302),
            parent: firstPopup
        )

        let destroyed = try graph.destroyClientRequestedPopup(secondPopup)

        #expect(destroyed.id == secondPopup)
        #expect(graph.popupStacksByRoot[rootSurface]?.topmost == firstPopup)
        #expect(graph.nodes[firstPopup]?.children.isEmpty == true)
        #expect(graph.nodes[secondPopup] == nil)
    }

    @Test
    func clientDestroyCascadeRemovesNestedPopupChainTopDown() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 35)
        let firstPopup = SurfaceID(rawValue: 36)
        let secondPopup = SurfaceID(rawValue: 37)
        let thirdPopup = SurfaceID(rawValue: 38)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 35))
        try graph.registerPopup(
            surfaceID: firstPopup,
            popupID: PopupID(rawValue: 351),
            parent: rootSurface
        )
        try graph.registerPopup(
            surfaceID: secondPopup,
            popupID: PopupID(rawValue: 352),
            parent: firstPopup
        )
        try graph.registerPopup(
            surfaceID: thirdPopup,
            popupID: PopupID(rawValue: 353),
            parent: secondPopup
        )

        let destroyed = try graph.destroyClientRequestedPopupCascade(secondPopup)

        #expect(destroyed.map(\.id) == [thirdPopup, secondPopup])
        #expect(graph.popupStacksByRoot[rootSurface]?.topmost == firstPopup)
        #expect(graph.nodes[thirdPopup] == nil)
        #expect(graph.nodes[secondPopup] == nil)
        #expect(graph.nodes[firstPopup]?.children.isEmpty == true)
        #expect(graph.livePopupSurfacesByID[PopupID(rawValue: 352)] == nil)
        #expect(graph.livePopupSurfacesByID[PopupID(rawValue: 353)] == nil)
    }

    @Test
    func compositorDismissalRemovesPopupChainTopDown() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 40)
        let firstPopup = SurfaceID(rawValue: 41)
        let secondPopup = SurfaceID(rawValue: 42)
        let thirdPopup = SurfaceID(rawValue: 43)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 4))
        try graph.registerPopup(
            surfaceID: firstPopup,
            popupID: PopupID(rawValue: 401),
            parent: rootSurface
        )
        try graph.registerPopup(
            surfaceID: secondPopup,
            popupID: PopupID(rawValue: 402),
            parent: firstPopup
        )
        try graph.registerPopup(
            surfaceID: thirdPopup,
            popupID: PopupID(rawValue: 403),
            parent: secondPopup
        )

        let dismissed = try graph.dismissPopupFromCompositor(secondPopup)

        #expect(dismissed.map(\.id) == [thirdPopup, secondPopup])
        #expect(graph.popupStacksByRoot[rootSurface]?.topmost == firstPopup)
        #expect(graph.nodes[thirdPopup] == nil)
        #expect(graph.nodes[secondPopup] == nil)
        #expect(graph.nodes[firstPopup]?.children.isEmpty == true)
        #expect(graph.nodes[rootSurface]?.children == [firstPopup])
    }

    @Test
    func toplevelCannotBeUnregisteredWhilePopupsAreLive() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 50)
        let popupSurface = SurfaceID(rawValue: 51)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 5))
        try graph.registerPopup(
            surfaceID: popupSurface,
            popupID: PopupID(rawValue: 501),
            parent: rootSurface
        )

        #expect(
            throws:
                DisplaySurfaceStoreError
                .toplevelDestroyedWithLivePopups(WindowID(rawValue: 5))
        ) {
            try graph.unregisterTopLevel(rootSurface)
        }
    }

    @Test
    func independentTopLevelPopupChainsDoNotBlockEachOther() throws {
        var graph = SurfaceGraph()
        let rootA = SurfaceID(rawValue: 60)
        let popupA = SurfaceID(rawValue: 61)
        let rootB = SurfaceID(rawValue: 70)
        let popupB = SurfaceID(rawValue: 71)

        try graph.registerTopLevel(surfaceID: rootA, windowID: WindowID(rawValue: 6))
        try graph.registerTopLevel(surfaceID: rootB, windowID: WindowID(rawValue: 7))
        try graph.registerPopup(
            surfaceID: popupA,
            popupID: PopupID(rawValue: 601),
            parent: rootA
        )
        try graph.registerPopup(
            surfaceID: popupB,
            popupID: PopupID(rawValue: 701),
            parent: rootB
        )

        let destroyedA = try graph.destroyClientRequestedPopup(popupA)

        #expect(destroyedA.id == popupA)
        #expect(graph.nodes[popupA] == nil)
        #expect(graph.nodes[popupB]?.id == popupB)
        #expect(graph.popupStacksByRoot[rootA]?.topmost == nil)
        #expect(graph.popupStacksByRoot[rootB]?.topmost == popupB)
    }

    @Test
    func compositorDismissalDoesNotCrossTopLevelRoots() throws {
        var graph = SurfaceGraph()
        let rootA = SurfaceID(rawValue: 80)
        let popupA = SurfaceID(rawValue: 81)
        let nestedPopupA = SurfaceID(rawValue: 82)
        let rootB = SurfaceID(rawValue: 90)
        let popupB = SurfaceID(rawValue: 91)

        try graph.registerTopLevel(surfaceID: rootA, windowID: WindowID(rawValue: 8))
        try graph.registerTopLevel(surfaceID: rootB, windowID: WindowID(rawValue: 9))
        try graph.registerPopup(
            surfaceID: popupA,
            popupID: PopupID(rawValue: 801),
            parent: rootA
        )
        try graph.registerPopup(
            surfaceID: nestedPopupA,
            popupID: PopupID(rawValue: 802),
            parent: popupA
        )
        try graph.registerPopup(
            surfaceID: popupB,
            popupID: PopupID(rawValue: 901),
            parent: rootB
        )

        let dismissed = try graph.dismissPopupFromCompositor(popupA)

        #expect(dismissed.map(\.id) == [nestedPopupA, popupA])
        #expect(graph.nodes[popupA] == nil)
        #expect(graph.nodes[nestedPopupA] == nil)
        #expect(graph.nodes[popupB]?.id == popupB)
        #expect(graph.popupStacksByRoot[rootA]?.topmost == nil)
        #expect(graph.popupStacksByRoot[rootB]?.topmost == popupB)
    }

    @Test
    func duplicateAndUnknownSurfaceTransitionsAreRejected() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 100)
        let popupSurface = SurfaceID(rawValue: 101)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 10))

        #expect(throws: DisplaySurfaceStoreError.duplicateSurface(rootSurface)) {
            try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 11))
        }
        #expect(throws: DisplaySurfaceStoreError.unknownParent(SurfaceID(rawValue: 999))) {
            try graph.registerPopup(
                surfaceID: popupSurface,
                popupID: PopupID(rawValue: 1_001),
                parent: SurfaceID(rawValue: 999)
            )
        }
        #expect(throws: DisplaySurfaceStoreError.unknownSurface(popupSurface)) {
            try graph.destroyClientRequestedPopup(popupSurface)
        }
        #expect(throws: DisplaySurfaceStoreError.unknownSurface(popupSurface)) {
            try graph.dismissPopupFromCompositor(popupSurface)
        }
    }
}

@Suite
struct SurfaceGraphIdentityTests {
    @Test
    func duplicatePopupIDIsRejected() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 120)
        let firstPopupSurface = SurfaceID(rawValue: 121)
        let secondPopupSurface = SurfaceID(rawValue: 122)
        let popupID = PopupID(rawValue: 1_201)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 12))
        try graph.registerPopup(
            surfaceID: firstPopupSurface,
            popupID: popupID,
            parent: rootSurface
        )

        #expect(throws: DisplaySurfaceStoreError.duplicatePopup(popupID)) {
            try graph.registerPopup(
                surfaceID: secondPopupSurface,
                popupID: popupID,
                parent: rootSurface
            )
        }
    }

    @Test
    func popupIDCanBeReusedAfterTerminalRemoval() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 130)
        let firstPopupSurface = SurfaceID(rawValue: 131)
        let secondPopupSurface = SurfaceID(rawValue: 132)
        let popupID = PopupID(rawValue: 1_301)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 13))
        try graph.registerPopup(
            surfaceID: firstPopupSurface,
            popupID: popupID,
            parent: rootSurface
        )
        _ = try graph.destroyClientRequestedPopup(firstPopupSurface)

        try graph.registerPopup(
            surfaceID: secondPopupSurface,
            popupID: popupID,
            parent: rootSurface
        )

        #expect(graph.livePopupSurfacesByID[popupID] == secondPopupSurface)
    }

    @Test
    func terminalPopupEventsAreRejectedAfterRemoval() throws {
        var graph = SurfaceGraph()
        let rootSurface = SurfaceID(rawValue: 110)
        let popupSurface = SurfaceID(rawValue: 111)

        try graph.registerTopLevel(surfaceID: rootSurface, windowID: WindowID(rawValue: 11))
        try graph.registerPopup(
            surfaceID: popupSurface,
            popupID: PopupID(rawValue: 1_101),
            parent: rootSurface
        )

        _ = try graph.dismissPopupFromCompositor(popupSurface)

        #expect(throws: DisplaySurfaceStoreError.unknownSurface(popupSurface)) {
            try graph.dismissPopupFromCompositor(popupSurface)
        }
        #expect(throws: DisplaySurfaceStoreError.unknownSurface(popupSurface)) {
            try graph.destroyClientRequestedPopup(popupSurface)
        }
    }
}
