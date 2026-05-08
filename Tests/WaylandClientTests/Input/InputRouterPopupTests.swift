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
        try router.registerPopup(
            popupID: PopupID(rawValue: 701),
            parentSurfaceID: 1_700,
            surfaceID: 1_701
        )

        #expect(router.windowID(for: 1_701) == parentWindowID)
        #expect(
            router.surfaceTarget(for: 1_701)
                == .popup(
                    PopupSurfaceIdentity(PopupID(rawValue: 701)),
                    parentWindowID: parentWindowID
                )
        )
    }

    @Test
    func popupRegistrationRejectsUnknownParentSurface() {
        let router = InputRouter()

        #expect(throws: InputRouterError.unknownParentSurface(9_999)) {
            try router.registerPopup(
                popupID: PopupID(rawValue: 701),
                parentSurfaceID: 9_999,
                surfaceID: 1_701
            )
        }
    }

    @Test
    func popupRegistrationDoesNotAcceptCallerSuppliedWindowID() throws {
        let router = InputRouter()
        let parentWindowID = WindowID(rawValue: 1)
        let unrelatedWindowID = WindowID(rawValue: 2)
        router.register(windowID: parentWindowID, surfaceID: 100)
        router.register(windowID: unrelatedWindowID, surfaceID: 200)
        try router.registerPopup(
            popupID: PopupID(rawValue: 101),
            parentSurfaceID: 100,
            surfaceID: 101
        )

        #expect(router.windowID(for: 101) == parentWindowID)
    }

    @Test
    func popupPointerTargetIncludesPopupIdentity() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 17)
        let windowID = WindowID(rawValue: 170)
        let popupID = PopupID(rawValue: 701)
        router.register(windowID: windowID, surfaceID: 1_700)
        try router.registerPopup(
            popupID: popupID,
            parentSurfaceID: 1_700,
            surfaceID: 1_701
        )

        let enter = router.route(
            rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 1_701, serial: 9)
        )
        let motion = router.route(
            rawPointerMotion(sequence: 2, seatID: seatID, time: 3)
        )

        #expect(enter.first?.windowID == windowID)
        #expect(motion.first?.windowID == windowID)
        #expect(enter.first?.popup == PopupSurfaceIdentity(popupID))
        #expect(motion.first?.popup == PopupSurfaceIdentity(popupID))
        #expect(
            enter.first?.target
                == .surface(.popup(PopupSurfaceIdentity(popupID), parentWindowID: windowID))
        )
    }

    @Test
    func popupKeyboardTargetIncludesPopupIdentity() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 18)
        let windowID = WindowID(rawValue: 180)
        let popupID = PopupID(rawValue: 801)
        router.register(windowID: windowID, surfaceID: 1_800)
        try router.registerPopup(
            popupID: popupID,
            parentSurfaceID: 1_800,
            surfaceID: 1_801
        )

        let enter = router.route(
            rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_801, serial: 10)
        )
        let key = router.route(
            rawKeyboardKey(sequence: 2, seatID: seatID, serial: 11)
        )

        #expect(enter.first?.windowID == windowID)
        #expect(key.first?.windowID == windowID)
        #expect(enter.first?.popup == PopupSurfaceIdentity(popupID))
        #expect(key.first?.popup == PopupSurfaceIdentity(popupID))
    }

    @Test
    func popupTouchTargetIncludesPopupIdentity() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 19)
        let windowID = WindowID(rawValue: 190)
        let popupID = PopupID(rawValue: 901)
        router.register(windowID: windowID, surfaceID: 1_900)
        try router.registerPopup(
            popupID: popupID,
            parentSurfaceID: 1_900,
            surfaceID: 1_901
        )

        let down = router.route(
            rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_901, id: 4)
        )
        let motion = router.route(rawTouchMotion(sequence: 2, seatID: seatID, id: 4))

        #expect(down.first?.windowID == windowID)
        #expect(motion.first?.windowID == windowID)
        #expect(down.first?.popup == PopupSurfaceIdentity(popupID))
        #expect(motion.first?.popup == PopupSurfaceIdentity(popupID))
    }

    @Test
    func nestedPopupInputTargetsLeafPopup() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 21)
        let windowID = WindowID(rawValue: 210)
        let parentPopupID = PopupID(rawValue: 2_101)
        let leafPopupID = PopupID(rawValue: 2_102)
        router.register(windowID: windowID, surfaceID: 2_100)
        try router.registerPopup(
            popupID: parentPopupID,
            parentSurfaceID: 2_100,
            surfaceID: 2_101
        )
        try router.registerPopup(
            popupID: leafPopupID,
            parentSurfaceID: 2_101,
            surfaceID: 2_102
        )

        let enter = router.route(
            rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 2_102, serial: 12)
        )

        #expect(enter.first?.windowID == windowID)
        #expect(enter.first?.popup == PopupSurfaceIdentity(leafPopupID))
        #expect(
            enter.first?.target
                == .surface(.popup(PopupSurfaceIdentity(leafPopupID), parentWindowID: windowID))
        )
    }

    @Test
    func popupCloseRemovesPopupTargetButKeepsParentTarget() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 22)
        let windowID = WindowID(rawValue: 220)
        let popupID = PopupID(rawValue: 2_201)
        router.register(windowID: windowID, surfaceID: 2_200)
        try router.registerPopup(
            popupID: popupID,
            parentSurfaceID: 2_200,
            surfaceID: 2_201
        )

        _ = router.route(rawPointerEnter(sequence: 1, seatID: seatID, surfaceID: 2_201))
        router.unregister(surfaceID: 2_201)

        let staleMotion = router.route(rawPointerMotion(sequence: 2, seatID: seatID, time: 20))
        let parentEnter = router.route(
            rawPointerEnter(sequence: 3, seatID: seatID, surfaceID: 2_200, serial: 21)
        )

        #expect(staleMotion.first?.target == .focusless)
        #expect(parentEnter.first?.target == .surface(.window(windowID)))
        #expect(parentEnter.first?.popup == nil)
    }

    @Test
    func unregisterPopupSurfaceClearsPointerKeyboardAndTouchFocus() throws {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 20)
        let windowID = WindowID(rawValue: 200)
        router.register(windowID: windowID, surfaceID: 2_000)
        try router.registerPopup(
            popupID: PopupID(rawValue: 2_001),
            parentSurfaceID: 2_000,
            surfaceID: 2_001
        )

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
