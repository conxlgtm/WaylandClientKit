import Testing
import WaylandKeyboardInterpretation
import WaylandRaw

@Suite
struct KeyboardLayoutStateTests {
    @Test
    func rejectsUnsupportedKeymapFormat() throws {
        let payload = keymapPayload(bytes: [], format: .noKeymap)

        do {
            _ = try KeyboardLayoutState(keymap: payload)
            Issue.record("Expected unsupported keymap format")
        } catch KeyboardInterpretationError.unsupportedKeymapFormat(let format) {
            #expect(format == RawKeyboardKeymapFormat.noKeymap.rawValue)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func rejectsInvalidKeymapEncoding() throws {
        let payload = keymapPayload(bytes: [0xFF])

        do {
            _ = try KeyboardLayoutState(keymap: payload)
            Issue.record("Expected invalid keymap encoding")
        } catch KeyboardInterpretationError.invalidKeymapEncoding {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func interpretsKeysFromXKBV1Keymap() throws {
        let layout = try KeyboardLayoutState(keymap: keymapPayload(text: testKeymap))
        let interpreted = layout.interpret(
            RawKeyboardKey(
                serial: 1,
                time: 2,
                evdevKeycode: 16,
                state: .pressed
            )
        )

        #expect(interpreted.evdevKeycode == 16)
        #expect(interpreted.xkbKeycode == 24)
        #expect(interpreted.keysymName == "q")
        #expect(interpreted.text == "q")
    }

    @Test
    func appliesClientModifierMasks() throws {
        let layout = try KeyboardLayoutState(keymap: keymapPayload(text: testKeymap))
        let shiftMask = try #require(layout.modifierMask(named: "Shift"))

        layout.applyModifiers(
            RawKeyboardModifiers(
                serial: 1,
                depressed: shiftMask,
                latched: 0,
                locked: 0,
                group: 0
            )
        )
        let interpreted = layout.interpret(
            RawKeyboardKey(
                serial: 2,
                time: 3,
                evdevKeycode: 16,
                state: .pressed
            )
        )

        #expect(interpreted.keysymName == "Q")
        #expect(interpreted.text == "Q")
    }

    @Test
    func eventInterpreterTracksKeymapModifiersAndKeys() throws {
        let interpreter = KeyboardEventInterpreter()
        let payload = keymapPayload(text: testKeymap)
        let shiftMask = try #require(
            try KeyboardLayoutState(keymap: payload).modifierMask(named: "Shift"))

        #expect(try interpreter.handle(.keymap(payload)) == nil)
        #expect(interpreter.currentKeymapID == payload.id)
        #expect(
            try interpreter.handle(
                .modifiers(
                    RawKeyboardModifiers(
                        serial: 1,
                        depressed: shiftMask,
                        latched: 0,
                        locked: 0,
                        group: 0
                    )
                )
            ) == nil)

        let interpreted = try #require(
            try interpreter.handle(
                .key(
                    RawKeyboardKey(
                        serial: 2,
                        time: 3,
                        evdevKeycode: 16,
                        state: .pressed
                    )
                )
            )
        )
        #expect(interpreted.text == "Q")

        #expect(try interpreter.handle(.keymap(keymapPayload(bytes: [], format: .noKeymap))) == nil)
        #expect(interpreter.currentKeymapID == nil)
    }

    @Test
    func eventInterpreterUsesRawInputDeviceIdentity() throws {
        let interpreter = KeyboardEventInterpreter()
        let deviceID = keyboardDevice()
        let payload = keymapPayload(
            text: testKeymap,
            seatID: deviceID.seatID,
            keyboardGeneration: deviceID.generation
        )

        #expect(
            try interpreter.handle(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(payload))
            ) == nil)
        #expect(interpreter.currentKeyboardDeviceID == deviceID)

        let interpreted = try #require(
            try interpreter.handle(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(
                        RawKeyboardKey(
                            serial: 3,
                            time: 4,
                            evdevKeycode: 16,
                            state: .pressed
                        )
                    ),
                    sequence: 2
                )
            )
        )

        #expect(interpreted.text == "q")
    }

    @Test
    func eventInterpreterRejectsMixedKeyboardDevices() throws {
        let interpreter = KeyboardEventInterpreter()
        let firstDevice = keyboardDevice(seatRawValue: 1, generation: 1)
        let secondDevice = keyboardDevice(seatRawValue: 1, generation: 2)
        let payload = keymapPayload(
            text: testKeymap,
            seatID: firstDevice.seatID,
            keyboardGeneration: firstDevice.generation
        )

        #expect(
            try interpreter.handle(
                rawKeyboardInputEvent(deviceID: firstDevice, kind: .keymap(payload))
            ) == nil)

        do {
            _ = try interpreter.handle(
                rawKeyboardInputEvent(
                    deviceID: secondDevice,
                    kind: .key(
                        RawKeyboardKey(
                            serial: 3,
                            time: 4,
                            evdevKeycode: 16,
                            state: .pressed
                        )
                    ),
                    sequence: 2
                )
            )
            Issue.record("Expected mixed keyboard device rejection")
        } catch KeyboardInterpretationError.mismatchedKeyboardDevice(let expected, let actual) {
            #expect(expected == firstDevice)
            #expect(actual == secondDevice)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func eventInterpreterResetsWhenSeatKeyboardGoesAway() throws {
        let interpreter = KeyboardEventInterpreter()
        let deviceID = keyboardDevice()
        let payload = keymapPayload(
            text: testKeymap,
            seatID: deviceID.seatID,
            keyboardGeneration: deviceID.generation
        )

        #expect(
            try interpreter.handle(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(payload))
            ) == nil)
        #expect(interpreter.currentKeyboardDeviceID == deviceID)

        #expect(
            try interpreter.handle(
                RawInputEvent(
                    sequence: 2,
                    seatID: deviceID.seatID,
                    deviceID: nil,
                    kind: .seatRemoved
                )
            ) == nil)

        #expect(interpreter.currentKeyboardDeviceID == nil)
        #expect(interpreter.currentKeymapID == nil)
    }
}

private func keymapPayload(
    bytes: [UInt8],
    format: RawKeyboardKeymapFormat = .xkbV1,
    seatID: RawSeatID = RawSeatID(rawValue: 1),
    keyboardGeneration: UInt64 = 1
) -> RawKeyboardKeymapPayload {
    RawKeyboardKeymapPayload(
        id: RawKeyboardKeymapID(
            seatID: seatID,
            keyboardGeneration: keyboardGeneration,
            keymapGeneration: 1
        ),
        format: format,
        size: UInt32(bytes.count),
        bytes: bytes
    )
}

private func keymapPayload(
    text: String,
    seatID: RawSeatID = RawSeatID(rawValue: 1),
    keyboardGeneration: UInt64 = 1
) -> RawKeyboardKeymapPayload {
    keymapPayload(
        bytes: Array(text.utf8),
        seatID: seatID,
        keyboardGeneration: keyboardGeneration
    )
}

private func keyboardDevice(
    seatRawValue: UInt32 = 1,
    generation: UInt64 = 1
) -> RawInputDeviceID {
    RawInputDeviceID(
        seatID: RawSeatID(rawValue: seatRawValue),
        kind: .keyboard,
        generation: generation
    )
}

private func rawKeyboardInputEvent(
    deviceID: RawInputDeviceID,
    kind: RawKeyboardEvent,
    sequence: UInt64 = 1
) -> RawInputEvent {
    RawInputEvent(
        sequence: sequence,
        seatID: deviceID.seatID,
        deviceID: deviceID,
        kind: .keyboard(kind)
    )
}

private let testKeymap = """
    xkb_keymap {
        xkb_keycodes "swiftwayland" {
            minimum = 8;
            maximum = 255;
            <LFSH> = 50;
            <AD01> = 24;
        };
        xkb_types "swiftwayland" {
            type "ONE_LEVEL" {
                modifiers = none;
                map[None] = Level1;
                level_name[Level1] = "Any";
            };
            type "TWO_LEVEL" {
                modifiers = Shift;
                map[Shift] = Level2;
                level_name[Level1] = "Base";
                level_name[Level2] = "Shift";
            };
        };
        xkb_compatibility "swiftwayland" {
        };
        xkb_symbols "swiftwayland" {
            key <LFSH> { [ Shift_L ] };
            modifier_map Shift { <LFSH> };
            key <AD01> { type="TWO_LEVEL", [ q, Q ] };
        };
    };
    """
