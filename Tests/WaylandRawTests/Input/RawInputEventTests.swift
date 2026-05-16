import Testing

@testable import WaylandRaw

@Suite
struct RawInputEventTests {
    @Test
    func rawInputEventCarriesSequenceSeatAndDeviceIdentity() {
        let seatID = RawSeatID(rawValue: 9)
        let deviceID = RawInputDeviceID(
            seatID: seatID,
            kind: .keyboard,
            generation: 2
        )
        let key = RawKeyboardKey(
            serial: 11,
            time: 22,
            evdevKeycode: 30,
            state: .pressed
        )
        let event = RawInputEvent(
            sequence: 44,
            seatID: seatID,
            deviceID: deviceID,
            kind: .keyboard(.key(key))
        )
        #expect(event.sequence == 44)
        #expect(event.seatID == seatID)
        #expect(event.deviceID == deviceID)
        #expect(event.kind == .keyboard(.key(key)))
    }
    @Test
    func seatSnapshotPreservesAdvertisedAndActiveCapabilities() throws {
        let snapshot = try RawSeatEventSnapshot(
            advertisedCapabilities: [.pointer, .keyboard],
            activeCapabilities: [.keyboard],
            name: "main"
        )
        #expect(snapshot.advertisedCapabilities == [.pointer, .keyboard])
        #expect(snapshot.activeCapabilities == [.keyboard])
        #expect(snapshot.name == "main")
    }
    @Test
    func seatSnapshotRejectsActiveCapabilityNotAdvertised() {
        #expect(
            throws: RawSeatEventSnapshotError.activeCapabilityNotAdvertised(
                activeCapabilities: [.keyboard],
                advertisedCapabilities: []
            )
        ) {
            _ = try RawSeatEventSnapshot(
                advertisedCapabilities: [],
                activeCapabilities: [.keyboard],
                name: nil
            )
        }
    }
    @Test
    func seatCapabilitiesDescriptionIncludesUnknownBits() {
        let capabilities = SeatCapabilities(rawValue: 0x80)
        #expect(capabilities.unknownBits == 0x80)
        #expect(capabilities.unknownRawValue == 0x80)
        #expect(capabilities.description == "unknown(0x80)")
        #expect(SeatCapabilities(rawValue: 0x81).description == "pointer+unknown(0x80)")
        #expect(SeatCapabilities.pointer.containsOnlyKnownBits)
    }
    @Test
    func pointerAxisComponentsPreserveRawValues() {
        let event = RawPointerAxisEvent.value120(
            axis: .verticalScroll,
            value120: -120
        )
        #expect(event == .value120(axis: .verticalScroll, value120: -120))
        #expect(RawPointerAxis(rawValue: 99).rawValue == 99)
        #expect(RawPointerAxisSource.wheelTilt.rawValue == 3)
        #expect(RawPointerAxisRelativeDirection.inverted.rawValue == 1)
    }
    @Test
    func pointerButtonStatePreservesUnknownFutureValues() {
        let future = RawPointerButtonState(rawValue: 99)
        #expect(RawPointerButtonState.released.rawValue == 0)
        #expect(RawPointerButtonState.pressed.rawValue == 1)
        #expect(future.rawValue == 99)
    }
    @Test
    func keyboardKeyStatePreservesRepeatedAndUnknownFutureValues() {
        let future = RawKeyboardKeyState(rawValue: 99)
        #expect(RawKeyboardKeyState.released.rawValue == 0)
        #expect(RawKeyboardKeyState.pressed.rawValue == 1)
        #expect(RawKeyboardKeyState.repeated.rawValue == 2)
        #expect(future.rawValue == 99)
    }
    @Test
    func keyboardKeymapInfoCarriesInternalIDAndSafeMetadata() throws {
        let seatID = RawSeatID(rawValue: 12)
        let id = RawKeyboardKeymapID(
            seatID: seatID,
            keyboardGeneration: 3,
            keymapGeneration: 4
        )
        let info = RawKeyboardKeymapInfo(
            id: id,
            format: .xkbV1,
            size: 128
        )
        let payload = try RawKeyboardKeymapPayload.xkbV1(
            id: id,
            bytes: [1, 2, 0]
        )
        #expect(info.id == id)
        #expect(info.format == .xkbV1)
        #expect(info.size == 128)
        #expect(RawKeyboardKeymapFormat.noKeymap.rawValue == 0)
        #expect(payload.size == 3)
        #expect(payload.xkbV1Bytes?.rawValue == [1, 2, 0])
    }
    @Test
    func touchEventsPreserveRawFields() {
        let down = RawTouchDown(
            serial: 1,
            time: 2,
            surfaceID: 99,
            id: 3,
            x: WaylandFixed(rawValue: 256),
            y: WaylandFixed(rawValue: 512)
        )
        let event = RawTouchEvent.down(down)
        #expect(down.id.rawValue == 3)
        #expect(event == .down(down))
    }
}
