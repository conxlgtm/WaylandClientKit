import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct TouchInputRouterTests {
    @Test
    func touchDownSetsFocusAndMotionRoutesToFocusedWindow() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 11)
        let windowID = WindowID(rawValue: 110)
        router.register(windowID: windowID, surfaceID: 1_100)

        let down = router.route(
            rawTouchDown(
                sequence: 1,
                seatID: seatID,
                surfaceID: 1_100,
                serial: 7,
                time: 8,
                id: 9,
                xRaw: 512,
                yRaw: 1_024
            )
        )
        let motion = router.route(
            rawTouchMotion(
                sequence: 2,
                seatID: seatID,
                time: 10,
                id: 9,
                xRaw: 1_536,
                yRaw: 2_048
            )
        )

        #expect(
            down.first?.kind
                == .touch(
                    .down(
                        TouchDownEvent(
                            serial: 7,
                            time: 8,
                            id: 9,
                            location: PointerLocation(x: 2.0, y: 4.0)
                        )
                    )
                ))
        #expect(down.first?.windowID == windowID)
        #expect(motion.first?.windowID == windowID)
        #expect(
            motion.first?.kind
                == .touch(
                    .motion(
                        TouchMotionEvent(
                            time: 10,
                            id: 9,
                            location: PointerLocation(x: 6.0, y: 8.0)
                        )
                    )
                ))
    }

    @Test
    func touchUpClearsFocusedTouchID() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 12)
        let windowID = WindowID(rawValue: 120)
        router.register(windowID: windowID, surfaceID: 1_200)

        _ = router.route(rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_200, id: 3))
        let up = router.route(rawTouchUp(sequence: 2, seatID: seatID, id: 3))
        let motion = router.route(rawTouchMotion(sequence: 3, seatID: seatID, id: 3))

        #expect(up.first?.windowID == windowID)
        #expect(up.first?.kind == .touch(.up(TouchUpEvent(serial: 4, time: 5, id: 3))))
        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .focusless)
    }

    @Test
    func touchShapeAndOrientationRouteToFocusedTouchID() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 13)
        let windowID = WindowID(rawValue: 130)
        router.register(windowID: windowID, surfaceID: 1_300)

        _ = router.route(rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_300, id: 7))
        let shape = router.route(rawTouchShape(sequence: 2, seatID: seatID, id: 7))
        let orientation = router.route(rawTouchOrientation(sequence: 3, seatID: seatID, id: 7))

        #expect(shape.first?.windowID == windowID)
        #expect(
            shape.first?.kind
                == .touch(.shape(TouchShapeEvent(id: 7, major: 2.0, minor: 1.0))))
        #expect(orientation.first?.windowID == windowID)
        #expect(
            orientation.first?.kind
                == .touch(.orientation(TouchOrientationEvent(id: 7, orientation: 0.5))))
    }

    @Test
    func touchCancelClearsSeatTouchFocuses() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 14)
        router.register(windowID: WindowID(rawValue: 140), surfaceID: 1_400)

        _ = router.route(rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_400, id: 1))
        let cancel = router.route(rawEvent(sequence: 2, seatID: seatID, kind: .touch(.cancel)))
        let motion = router.route(rawTouchMotion(sequence: 3, seatID: seatID, id: 1))

        #expect(cancel.first?.windowID == nil)
        #expect(cancel.first?.kind == .touch(.cancel))
        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .focusless)
    }

    @Test
    func unregisterClearsTouchFocusForSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 16)
        router.register(windowID: WindowID(rawValue: 160), surfaceID: 1_600)

        _ = router.route(rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_600, id: 4))
        router.unregister(surfaceID: 1_600)
        let motion = router.route(rawTouchMotion(sequence: 2, seatID: seatID, id: 4))

        #expect(motion.first?.windowID == nil)
        #expect(motion.first?.target == .focusless)
    }

    @Test
    func touchMotionUpShapeOrientationAfterUnknownSurfaceDownStayUnmanagedSurface() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 19)

        let down = router.route(
            rawTouchDown(sequence: 1, seatID: seatID, surfaceID: 1_900, id: 5)
        )
        let motion = router.route(rawTouchMotion(sequence: 2, seatID: seatID, id: 5))
        let shape = router.route(rawTouchShape(sequence: 3, seatID: seatID, id: 5))
        let orientation = router.route(rawTouchOrientation(sequence: 4, seatID: seatID, id: 5))
        let up = router.route(rawTouchUp(sequence: 5, seatID: seatID, id: 5))
        let motionAfterUp = router.route(rawTouchMotion(sequence: 6, seatID: seatID, id: 5))

        #expect(down.first?.target == .unmanagedSurface)
        #expect(motion.first?.target == .unmanagedSurface)
        #expect(shape.first?.target == .unmanagedSurface)
        #expect(orientation.first?.target == .unmanagedSurface)
        #expect(up.first?.target == .unmanagedSurface)
        #expect(motionAfterUp.first?.windowID == nil)
        #expect(motionAfterUp.first?.target == .focusless)
    }
}
