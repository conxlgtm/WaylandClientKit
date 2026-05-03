import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct InputDeviceGraphOwnershipTests {
    @Test
    func pointerCapabilityRemovalRetiresCurrentDeviceGeneration() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 17)
        let firstPointer = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let secondPointer = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 2)
        router.register(windowID: WindowID(rawValue: 170), surfaceID: 1_700)
        router.register(windowID: WindowID(rawValue: 171), surfaceID: 1_701)

        _ = router.route(
            rawPointerEnter(
                sequence: 1,
                seatID: seatID,
                surfaceID: 1_700,
                deviceID: firstPointer
            )
        )
        removeAllCapabilities(from: router, sequence: 2, seatID: seatID)

        let staleEnter = router.route(
            rawPointerEnter(
                sequence: 3,
                seatID: seatID,
                surfaceID: 1_701,
                deviceID: firstPointer
            )
        )
        let replacementEnter = router.route(
            rawPointerEnter(
                sequence: 4,
                seatID: seatID,
                surfaceID: 1_701,
                deviceID: secondPointer
            )
        )
        let staleMotion = router.route(
            rawPointerMotion(
                sequence: 5,
                seatID: seatID,
                time: 5,
                deviceID: firstPointer
            )
        )
        let replacementMotion = router.route(
            rawPointerMotion(
                sequence: 6,
                seatID: seatID,
                time: 6,
                deviceID: secondPointer
            )
        )

        #expect(staleEnter.isEmpty)
        #expect(replacementEnter.first?.windowID == WindowID(rawValue: 171))
        #expect(staleMotion.isEmpty)
        #expect(replacementMotion.first?.windowID == WindowID(rawValue: 171))
    }

    @Test
    func replacementPointerGenerationDoesNotInheritPriorFocus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 18)
        let firstPointer = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let secondPointer = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 2)
        router.register(windowID: WindowID(rawValue: 180), surfaceID: 1_800)

        _ = router.route(
            rawPointerEnter(
                sequence: 1,
                seatID: seatID,
                surfaceID: 1_800,
                deviceID: firstPointer
            )
        )
        let replacementMotion = router.route(
            rawPointerMotion(
                sequence: 2,
                seatID: seatID,
                time: 2,
                deviceID: secondPointer
            )
        )

        #expect(replacementMotion.first?.windowID == nil)
    }

    @Test
    func replacementTouchGenerationDoesNotInheritPriorFocus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 21)
        let firstTouch = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 1)
        let secondTouch = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 2)
        router.register(windowID: WindowID(rawValue: 210), surfaceID: 2_100)

        _ = router.route(
            rawTouchDown(
                sequence: 1,
                seatID: seatID,
                surfaceID: 2_100,
                id: 7,
                deviceID: firstTouch
            )
        )
        let replacementMotion = router.route(
            rawTouchMotion(sequence: 2, seatID: seatID, id: 7, deviceID: secondTouch)
        )

        #expect(replacementMotion.first?.windowID == nil)
    }

    @Test
    func keyboardCapabilityRemovalRetiresCurrentDeviceGeneration() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 19)
        let firstKeyboard = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)
        let secondKeyboard = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 2)
        router.register(windowID: WindowID(rawValue: 190), surfaceID: 1_900)
        router.register(windowID: WindowID(rawValue: 191), surfaceID: 1_901)

        _ = router.route(
            rawKeyboardEnter(
                sequence: 1,
                seatID: seatID,
                surfaceID: 1_900,
                deviceID: firstKeyboard
            )
        )
        removeAllCapabilities(from: router, sequence: 2, seatID: seatID)

        let staleEnter = router.route(
            rawKeyboardEnter(
                sequence: 3,
                seatID: seatID,
                surfaceID: 1_901,
                deviceID: firstKeyboard
            )
        )
        let replacementEnter = router.route(
            rawKeyboardEnter(
                sequence: 4,
                seatID: seatID,
                surfaceID: 1_901,
                deviceID: secondKeyboard
            )
        )
        let staleKey = router.route(
            rawKeyboardKey(sequence: 5, seatID: seatID, deviceID: firstKeyboard)
        )
        let replacementKey = router.route(
            rawKeyboardKey(sequence: 6, seatID: seatID, deviceID: secondKeyboard)
        )

        #expect(staleEnter.isEmpty)
        #expect(replacementEnter.first?.windowID == WindowID(rawValue: 191))
        #expect(staleKey.isEmpty)
        #expect(replacementKey.first?.windowID == WindowID(rawValue: 191))
    }

    @Test
    func touchCapabilityRemovalRetiresCurrentDeviceGeneration() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 20)
        let firstTouch = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 1)
        let secondTouch = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 2)
        router.register(windowID: WindowID(rawValue: 200), surfaceID: 2_000)
        router.register(windowID: WindowID(rawValue: 201), surfaceID: 2_001)

        _ = router.route(
            rawTouchDown(
                sequence: 1,
                seatID: seatID,
                surfaceID: 2_000,
                id: 4,
                deviceID: firstTouch
            )
        )
        removeAllCapabilities(from: router, sequence: 2, seatID: seatID)

        let staleDown = router.route(
            rawTouchDown(
                sequence: 3,
                seatID: seatID,
                surfaceID: 2_001,
                id: 4,
                deviceID: firstTouch
            )
        )
        let replacementDown = router.route(
            rawTouchDown(
                sequence: 4,
                seatID: seatID,
                surfaceID: 2_001,
                id: 4,
                deviceID: secondTouch
            )
        )
        let staleMotion = router.route(
            rawTouchMotion(sequence: 5, seatID: seatID, id: 4, deviceID: firstTouch)
        )
        let replacementMotion = router.route(
            rawTouchMotion(sequence: 6, seatID: seatID, id: 4, deviceID: secondTouch)
        )

        #expect(staleDown.isEmpty)
        #expect(replacementDown.first?.windowID == WindowID(rawValue: 201))
        #expect(staleMotion.isEmpty)
        #expect(replacementMotion.first?.windowID == WindowID(rawValue: 201))
    }

    private func removeAllCapabilities(
        from router: InputRouter,
        sequence: UInt64,
        seatID: RawSeatID
    ) {
        _ = router.route(
            rawSeatChanged(
                sequence: sequence,
                seatID: seatID,
                name: "seat0",
                advertisedCapabilities: [],
                activeCapabilities: []
            )
        )
    }
}

@Suite
struct InputDeviceGraphMalformedIdentityTests {
    @Test
    func pointerEventWithKeyboardDeviceIDIsDropped() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 22)
        let keyboardDevice = RawInputDeviceID(
            seatID: seatID,
            kind: .keyboard,
            generation: 1
        )
        router.register(windowID: WindowID(rawValue: 220), surfaceID: 2_200)

        let routed = router.route(
            rawPointerEnter(
                sequence: 1,
                seatID: seatID,
                surfaceID: 2_200,
                deviceID: keyboardDevice
            )
        )

        #expect(routed.isEmpty)
    }

    @Test
    func keyboardEventWithDifferentSeatDeviceIDIsDropped() {
        let router = InputRouter()
        let eventSeatID = RawSeatID(rawValue: 23)
        let deviceSeatID = RawSeatID(rawValue: 24)
        let keyboardDevice = RawInputDeviceID(
            seatID: deviceSeatID,
            kind: .keyboard,
            generation: 1
        )
        router.register(windowID: WindowID(rawValue: 230), surfaceID: 2_300)

        let routed = router.route(
            rawKeyboardEnter(
                sequence: 1,
                seatID: eventSeatID,
                surfaceID: 2_300,
                deviceID: keyboardDevice
            )
        )

        #expect(routed.isEmpty)
    }

    @Test
    func malformedDeviceIDDoesNotAdoptOrClearExistingFocus() {
        let router = InputRouter()
        let seatID = RawSeatID(rawValue: 25)
        let pointerDevice = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
        let keyboardDevice = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)
        router.register(windowID: WindowID(rawValue: 250), surfaceID: 2_500)

        _ = router.route(
            rawPointerEnter(
                sequence: 1,
                seatID: seatID,
                surfaceID: 2_500,
                deviceID: pointerDevice
            )
        )
        let malformedLeave = router.route(
            rawPointerLeave(
                sequence: 2,
                seatID: seatID,
                surfaceID: 2_500,
                deviceID: keyboardDevice
            )
        )
        let validMotion = router.route(
            rawPointerMotion(
                sequence: 3,
                seatID: seatID,
                time: 3,
                deviceID: pointerDevice
            )
        )

        #expect(malformedLeave.isEmpty)
        #expect(validMotion.first?.windowID == WindowID(rawValue: 250))
    }
}
