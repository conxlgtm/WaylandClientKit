import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PopupInputRouterTests {
    @Test
    func popupRegistrationInheritsParentWindowID() throws {
        let router = InputRouter()
        let parentWindowID = WindowID(rawValue: 170)
        router.register(windowID: parentWindowID, surfaceID: 1_700)
        try router.registerPopup(parentSurfaceID: 1_700, surfaceID: 1_701)

        #expect(router.windowID(for: 1_701) == parentWindowID)
    }

    @Test
    func popupRegistrationRejectsUnknownParentSurface() {
        let router = InputRouter()

        #expect(throws: InputRouterError.unknownParentSurface(9_999)) {
            try router.registerPopup(parentSurfaceID: 9_999, surfaceID: 1_701)
        }
    }

    @Test
    func popupRegistrationDoesNotAcceptCallerSuppliedWindowID() throws {
        let router = InputRouter()
        let parentWindowID = WindowID(rawValue: 1)
        let unrelatedWindowID = WindowID(rawValue: 2)
        router.register(windowID: parentWindowID, surfaceID: 100)
        router.register(windowID: unrelatedWindowID, surfaceID: 200)
        try router.registerPopup(parentSurfaceID: 100, surfaceID: 101)

        #expect(router.windowID(for: 101) == parentWindowID)
    }

    @Test
    func popupPointerSurfaceRoutesToParentWindow() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 17)
        let windowID = WindowID(rawValue: 170)
        router.register(windowID: windowID, surfaceID: 1_700)
        try router.registerPopup(parentSurfaceID: 1_700, surfaceID: 1_701)

        let enter = router.route(
            rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 1_701, serial: 9)
        )
        let motion = router.route(
            rawPointerMotion(sequence: 2, seatID: seatID, time: 3)
        )

        #expect(enter.first?.windowID == windowID)
        #expect(motion.first?.windowID == windowID)
    }

    @Test
    func popupKeyboardSurfaceRoutesToParentWindow() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 18)
        let windowID = WindowID(rawValue: 180)
        router.register(windowID: windowID, surfaceID: 1_800)
        try router.registerPopup(parentSurfaceID: 1_800, surfaceID: 1_801)

        let enter = router.route(
            rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_801, serial: 10)
        )
        let key = router.route(
            rawKeyboardKey(sequence: 2, seatID: seatID, serial: 11)
        )

        #expect(enter.first?.windowID == windowID)
        #expect(key.first?.windowID == windowID)
    }

    @Test
    func popupTouchSurfaceRoutesToParentWindow() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 19)
        let windowID = WindowID(rawValue: 190)
        router.register(windowID: windowID, surfaceID: 1_900)
        try router.registerPopup(parentSurfaceID: 1_900, surfaceID: 1_901)

        let down = router.route(
            rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_901, id: 4)
        )
        let motion = router.route(rawTouchMotion(sequence: 2, seatID: seatID, id: 4))

        #expect(down.first?.windowID == windowID)
        #expect(motion.first?.windowID == windowID)
    }

    @Test
    func unregisterPopupSurfaceClearsPointerKeyboardAndTouchFocus() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 20)
        let windowID = WindowID(rawValue: 200)
        router.register(windowID: windowID, surfaceID: 2_000)
        try router.registerPopup(parentSurfaceID: 2_000, surfaceID: 2_001)

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 2_001))
        _ = router.route(rawKeyboardEnter(sequence: 2, seatID: seatID, surfaceID: 2_001))
        _ = router.route(rawTouchDown(sequence: 3, seatID: seatID, surfaceID: 2_001, id: 5))

        router.unregister(surfaceID: 2_001)

        let pointerMotion = router.route(rawPointerMotion(sequence: 4, seatID: seatID, time: 4))
        let key = router.route(rawKeyboardKey(sequence: 5, seatID: seatID))
        let touchMotion = router.route(rawTouchMotion(sequence: 6, seatID: seatID, id: 5))

        #expect(pointerMotion.first?.windowID == nil)
        #expect(key.first?.windowID == nil)
        #expect(touchMotion.first?.windowID == nil)
    }
}
