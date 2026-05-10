import Testing

@testable import WaylandClient

@Suite
struct DisplaySurfaceStoreTests {
    private typealias Store = DisplaySurfaceStore<WindowRef, PopupRef>

    private struct WindowRef: DisplayWindowReference {
        let displayWindowID: WindowID
    }

    private struct PopupRef: DisplayPopupReference {
        let displayPopupID: PopupID
    }

    @Test
    func allWindowIDsAreReturnedInStableRawValueOrder() throws {
        var store = Store()

        try store.insertWindow(
            WindowRef(displayWindowID: WindowID(rawValue: 30)),
            surfaceID: SurfaceID(rawValue: 300)
        )
        try store.insertWindow(
            WindowRef(displayWindowID: WindowID(rawValue: 10)),
            surfaceID: SurfaceID(rawValue: 100)
        )
        try store.insertWindow(
            WindowRef(displayWindowID: WindowID(rawValue: 20)),
            surfaceID: SurfaceID(rawValue: 200)
        )

        #expect(
            store.allWindowIDs == [
                WindowID(rawValue: 10),
                WindowID(rawValue: 20),
                WindowID(rawValue: 30),
            ]
        )
    }

    @Test
    func clientRequestedCascadeMarksRemovedPopupsClosing() throws {
        var store = try nestedPopupStore()

        let closingPopupIDs = try store.beginClientRequestedPopupCascade(
            PopupID(rawValue: 102)
        )

        #expect(closingPopupIDs == [PopupID(rawValue: 103), PopupID(rawValue: 102)])
        #expect(store.popupIsClosing(PopupID(rawValue: 103)))
        #expect(store.popupIsClosing(PopupID(rawValue: 102)))
        #expect(!store.popupIsClosing(PopupID(rawValue: 101)))
        #expect(
            store.popupIDsTopDown(parentedBy: WindowID(rawValue: 1))
                == [PopupID(rawValue: 101)]
        )
        try store.checkInvariantsForTesting()
    }

    @Test
    func compositorDismissalReturnsTopDownEvents() throws {
        var store = try nestedPopupStore()

        let dismissal = try #require(
            try store.beginCompositorPopupDismissal(PopupID(rawValue: 102))
        )

        #expect(dismissal.popupIDs == [PopupID(rawValue: 103), PopupID(rawValue: 102)])
        #expect(
            dismissal.events == [
                PopupLifecycleEvent(
                    popup: PopupID(rawValue: 103),
                    parentWindowID: WindowID(rawValue: 1)
                ),
                PopupLifecycleEvent(
                    popup: PopupID(rawValue: 102),
                    parentWindowID: WindowID(rawValue: 1)
                ),
            ]
        )
        #expect(store.popupIsClosing(PopupID(rawValue: 103)))
        #expect(store.popupIsClosing(PopupID(rawValue: 102)))
        #expect(
            store.popupIDsTopDown(parentedBy: WindowID(rawValue: 1))
                == [PopupID(rawValue: 101)]
        )
        try store.checkInvariantsForTesting()
    }

    @Test
    func compositorDismissFromMiddleMaintainsSurfaceTree() throws {
        var store = try nestedPopupStore()

        _ = try #require(
            try store.beginCompositorPopupDismissal(PopupID(rawValue: 102))
        )
        _ = store.markPopupClosed(PopupID(rawValue: 103))
        _ = store.markPopupClosed(PopupID(rawValue: 102))

        #expect(
            store.popupIDsTopDown(parentedBy: WindowID(rawValue: 1))
                == [PopupID(rawValue: 101)]
        )
        #expect(try store.windowID(for: SurfaceID(rawValue: 11)) == WindowID(rawValue: 1))
        #expect(store.popup(PopupID(rawValue: 102)) == nil)
        #expect(store.popup(PopupID(rawValue: 103)) == nil)
        try store.checkInvariantsForTesting()
    }

    @Test
    func markPopupClosedRemovesRecordAndPreservesParent() throws {
        var store = try nestedPopupStore()

        _ = try store.beginClientRequestedPopupCascade(PopupID(rawValue: 102))

        #expect(
            store.markPopupClosed(PopupID(rawValue: 103))
                == WindowID(rawValue: 1)
        )
        #expect(
            store.markPopupClosed(PopupID(rawValue: 102))
                == WindowID(rawValue: 1)
        )
        #expect(store.popup(PopupID(rawValue: 103)) == nil)
        #expect(store.popup(PopupID(rawValue: 102)) == nil)
        #expect(store.popupIsClosedOrClosing(PopupID(rawValue: 103)))
        #expect(store.popupIsClosedOrClosing(PopupID(rawValue: 102)))
        #expect(
            store.popupIDsTopDown(parentedBy: WindowID(rawValue: 1))
                == [PopupID(rawValue: 101)]
        )
        try store.checkInvariantsForTesting()
    }

    @Test
    func closedPopupIDCanBeReusedOnlyAfterOldRecordIsGone() throws {
        var store = try nestedPopupStore()
        let popupID = PopupID(rawValue: 102)

        _ = try store.beginClientRequestedPopupCascade(popupID)
        _ = store.markPopupClosed(popupID)
        _ = store.markPopupClosed(PopupID(rawValue: 103))

        try store.insertPopup(
            PopupRef(displayPopupID: popupID),
            surfaceID: SurfaceID(rawValue: 20),
            parent: SurfaceID(rawValue: 11)
        )

        #expect(!store.popupIsClosedOrClosing(popupID))
        #expect(
            store.popupIDsTopDown(parentedBy: WindowID(rawValue: 1))
                == [popupID, PopupID(rawValue: 101)]
        )
        try store.checkInvariantsForTesting()
    }

    private func nestedPopupStore() throws -> Store {
        var store = Store()
        try store.insertWindow(
            WindowRef(displayWindowID: WindowID(rawValue: 1)),
            surfaceID: SurfaceID(rawValue: 10)
        )
        try store.insertPopup(
            PopupRef(displayPopupID: PopupID(rawValue: 101)),
            surfaceID: SurfaceID(rawValue: 11),
            parent: SurfaceID(rawValue: 10)
        )
        try store.insertPopup(
            PopupRef(displayPopupID: PopupID(rawValue: 102)),
            surfaceID: SurfaceID(rawValue: 12),
            parent: SurfaceID(rawValue: 11)
        )
        try store.insertPopup(
            PopupRef(displayPopupID: PopupID(rawValue: 103)),
            surfaceID: SurfaceID(rawValue: 13),
            parent: SurfaceID(rawValue: 12)
        )
        return store
    }
}
