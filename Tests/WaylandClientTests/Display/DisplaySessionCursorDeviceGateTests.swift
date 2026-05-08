import Testing
import WaylandKeyboard
import WaylandRaw

@testable import WaylandClient

@Suite
struct DisplaySessionCursorDeviceGateTests {
    @Test
    func stalePointerEnterDoesNotApplyCursorBeforeRouting() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter()
        let backend = try RecordingCursorBackend()
        let cursorManager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 30)
        let currentPointer = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 2
        )
        let stalePointer = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )
        let currentEnter = rawPointerEnter(
            sequence: 1,
            seatID: seatID,
            surfaceID: 3_000,
            serial: 31,
            deviceID: currentPointer
        )
        let staleEnter = rawPointerEnter(
            sequence: 2,
            seatID: seatID,
            surfaceID: 3_001,
            serial: 32,
            deviceID: stalePointer
        )
        cursorManager.register(surfaceID: 3_000)
        cursorManager.register(surfaceID: 3_001)

        _ = routeSessionInputEvents(
            from: [currentEnter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )
        backend.setCursorRequests.removeAll()

        let routed = routeSessionInputEvents(
            from: [staleEnter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )

        #expect(routed.isEmpty)
        #expect(backend.setCursorRequests.isEmpty)
    }

    @Test
    func malformedPointerLeaveDoesNotClearCursorFocusBeforeRouting() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter()
        let backend = try RecordingCursorBackend()
        let cursorManager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 31)
        let pointerDevice = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let keyboardDevice = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)
        let pointerEnter = rawPointerEnter(
            sequence: 1,
            seatID: seatID,
            surfaceID: 3_100,
            serial: 41,
            deviceID: pointerDevice
        )
        let malformedPointerLeave = rawPointerLeave(
            sequence: 2,
            seatID: seatID,
            surfaceID: 3_100,
            deviceID: keyboardDevice
        )
        cursorManager.register(surfaceID: 3_100)

        _ = routeSessionInputEvents(
            from: [pointerEnter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )
        backend.setCursorRequests.removeAll()

        let malformedRouted = routeSessionInputEvents(
            from: [malformedPointerLeave],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )
        let explicitResults = try cursorManager.setPointerCursor(.text)

        #expect(malformedRouted.isEmpty)
        #expect(
            explicitResults
                == [.set(seatID: SeatID(rawValue: 31), serial: 41, cursor: .text)]
        )
        #expect(backend.setCursorRequests.map(\.serial) == [41])
    }

    @Test
    func pointerCapabilityRemovalRejectsStaleCursorApplication() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter()
        let backend = try RecordingCursorBackend()
        let cursorManager = try CursorManager(backend: backend, configuration: .init())
        let seatID = RawSeatID(rawValue: 32)
        let pointerDevice = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let stalePointerEnter = rawPointerEnter(
            sequence: 3,
            seatID: seatID,
            surfaceID: 3_200,
            serial: 52,
            deviceID: pointerDevice
        )
        cursorManager.register(surfaceID: 3_200)

        _ = routeSessionInputEvents(
            from: [
                rawPointerEnter(
                    sequence: 1,
                    seatID: seatID,
                    surfaceID: 3_200,
                    serial: 51,
                    deviceID: pointerDevice
                ),
                rawSeatChanged(
                    sequence: 2,
                    seatID: seatID,
                    name: "seat0",
                    advertisedCapabilities: [],
                    activeCapabilities: []
                ),
            ],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )
        backend.setCursorRequests.removeAll()

        let staleRouted = routeSessionInputEvents(
            from: [stalePointerEnter],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )

        #expect(staleRouted.isEmpty)
        #expect(backend.setCursorRequests.isEmpty)
    }
}
