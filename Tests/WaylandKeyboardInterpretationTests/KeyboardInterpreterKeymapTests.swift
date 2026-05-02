import Testing
import WaylandRaw

@testable import WaylandKeyboardInterpretation

@Suite
struct KeyboardInterpreterKeymapTests {
    @Test
    func parsesXKBV1KeymapAndEmitsKeymapEvent() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let payload = try keymapPayload(text: try fixtureKeymapText())
        let event = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(payload)))
                .first
        )

        #expect(event.sequence == 1)
        #expect(event.seatID == deviceID.seatID)
        #expect(event.deviceID == deviceID)
        #expect(interpreter.keymapID(for: deviceID) == payload.id)
        #expect(
            event.kind
                == .keymap(
                    InterpretedKeyboardKeymap(
                        id: payload.id,
                        format: .xkbV1,
                        size: payload.size
                    )
                ))
    }

    @Test
    func invalidKeymapBytesProduceDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let payload = try keymapPayload(bytes: Array("not a keymap".utf8) + [0])
        let event = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(payload)))
                .first
        )

        #expect(event.kind == unavailable(.invalidKeymap))
        #expect(interpreter.keymapID(for: deviceID) == nil)
    }

    @Test
    func noKeymapProducesUnsupportedFormatAndClearsPriorState() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let validPayload = try keymapPayload(text: try fixtureKeymapText())
        let noKeymap = try keymapPayload(bytes: [], format: .noKeymap)

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(validPayload)))
        #expect(interpreter.keymapID(for: deviceID) == validPayload.id)

        let event = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(noKeymap)))
                .first
        )

        #expect(
            event.kind
                == unavailable(
                    .unsupportedKeymapFormat(RawKeyboardKeymapFormat.noKeymap.rawValue)
                ))
        #expect(interpreter.keymapID(for: deviceID) == nil)
    }

    @Test
    func keyBeforeKeymapProducesMissingKeymapDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()), sequence: 2)
            )
            .first
        )

        #expect(event.kind == unavailable(.missingKeymap))
    }

    @Test
    func keyWithoutDeviceIDProducesMissingDeviceDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let event = try #require(
            interpreter.consume(
                RawInputEvent(
                    sequence: 7,
                    seatID: RawSeatID(rawValue: 1),
                    deviceID: nil,
                    kind: .keyboard(.key(qKey()))
                )
            ).first
        )

        #expect(event.kind == unavailable(.missingDeviceID))
    }

    @Test
    func keyFromNonKeyboardDeviceProducesDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 1),
            kind: .pointer,
            generation: 1
        )
        let event = try #require(
            interpreter.consume(
                RawInputEvent(
                    sequence: 7,
                    seatID: deviceID.seatID,
                    deviceID: deviceID,
                    kind: .keyboard(.key(qKey()))
                )
            ).first
        )

        #expect(event.kind == unavailable(.nonKeyboardInputDevice(deviceID)))
    }

    @Test
    func keyFromDifferentSeatProducesDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let eventSeatID = RawSeatID(rawValue: 1)
        let deviceSeatID = RawSeatID(rawValue: 2)
        let deviceID = RawInputDeviceID(
            seatID: deviceSeatID,
            kind: .keyboard,
            generation: 1
        )
        let event = try #require(
            interpreter.consume(
                RawInputEvent(
                    sequence: 8,
                    seatID: eventSeatID,
                    deviceID: deviceID,
                    kind: .keyboard(.key(qKey()))
                )
            ).first
        )

        #expect(
            event.kind
                == unavailable(.mismatchedKeyboardSeat(expected: eventSeatID, actual: deviceSeatID))
        )
    }

    @Test
    func keymapWithMismatchedDeviceProducesDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let payload = try keymapPayload(text: try fixtureKeymapText(), keyboardGeneration: 1)
        let eventDeviceID = keyboardDevice(generation: 2)
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: eventDeviceID, kind: .keymap(payload))
            ).first
        )

        #expect(
            event.kind
                == unavailable(
                    .mismatchedKeyboardDevice(
                        expected: keyboardDevice(generation: 1),
                        actual: eventDeviceID
                    )
                ))
    }

    @Test
    func keymapFromDifferentSeatProducesDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let eventSeatID = RawSeatID(rawValue: 1)
        let payloadSeatID = RawSeatID(rawValue: 2)
        let payload = try keymapPayload(text: try fixtureKeymapText(), seatID: payloadSeatID)
        let event = try #require(
            interpreter.consume(
                RawInputEvent(
                    sequence: 9,
                    seatID: eventSeatID,
                    deviceID: nil,
                    kind: .keyboard(.keymap(payload))
                )
            ).first
        )

        #expect(
            event.kind
                == unavailable(
                    .mismatchedKeyboardSeat(expected: eventSeatID, actual: payloadSeatID))
        )
    }

    @Test
    func keymapReplacementUpdatesStoredGeneration() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let first = try keymapPayload(text: try fixtureKeymapText(), keymapGeneration: 1)
        let second = try keymapPayload(text: try fixtureKeymapText(), keymapGeneration: 2)

        _ = interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(first)))
        #expect(interpreter.keymapID(for: deviceID) == first.id)

        _ = interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(second)))
        #expect(interpreter.keymapID(for: deviceID) == second.id)
    }
}
