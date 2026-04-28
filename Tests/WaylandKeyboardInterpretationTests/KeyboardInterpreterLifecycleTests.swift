import Testing
import WaylandRaw

@testable import WaylandKeyboardInterpretation

@Suite
struct KeyboardInterpreterLifecycleTests {
    @Test
    func seatRemovalClearsAllStatesForSeat() throws {
        let interpreter = try KeyboardInterpreter()
        let first = keyboardDevice(seatRawValue: 1, generation: 1)
        let second = keyboardDevice(seatRawValue: 1, generation: 2)
        let otherSeat = keyboardDevice(seatRawValue: 2, generation: 1)

        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: first,
                kind: .keymap(
                    keymapPayload(
                        text: try fixtureKeymapText(), keyboardGeneration: first.generation))
            )
        )
        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: second,
                kind: .keymap(
                    keymapPayload(
                        text: try fixtureKeymapText(), keyboardGeneration: second.generation))
            ))
        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: otherSeat,
                kind: .keymap(
                    keymapPayload(
                        text: try fixtureKeymapText(),
                        seatID: otherSeat.seatID,
                        keyboardGeneration: otherSeat.generation
                    ))))

        _ = interpreter.consume(
            RawInputEvent(
                sequence: 5,
                seatID: RawSeatID(rawValue: 1),
                deviceID: nil,
                kind: .seatRemoved
            )
        )

        #expect(interpreter.keymapID(for: first) == nil)
        #expect(interpreter.keymapID(for: second) == nil)
        #expect(interpreter.keymapID(for: otherSeat) != nil)
    }

    @Test
    func keyboardCapabilityLossClearsStatesForSeat() throws {
        let interpreter = try KeyboardInterpreter()
        let firstSeat = keyboardDevice(seatRawValue: 1)
        let secondSeat = keyboardDevice(seatRawValue: 2)

        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: firstSeat,
                kind: .keymap(keymapPayload(text: try fixtureKeymapText()))
            )
        )
        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: secondSeat,
                kind: .keymap(
                    keymapPayload(text: try fixtureKeymapText(), seatID: secondSeat.seatID))
            )
        )

        _ = interpreter.consume(
            RawInputEvent(
                sequence: 6,
                seatID: firstSeat.seatID,
                deviceID: nil,
                kind: .seat(
                    RawSeatEventSnapshot(
                        advertisedCapabilities: [.pointer],
                        activeCapabilities: [.pointer],
                        name: "seat0"
                    )
                )
            )
        )

        #expect(interpreter.keymapID(for: firstSeat) == nil)
        #expect(interpreter.keymapID(for: secondSeat) != nil)
    }

    @Test
    func deviceGenerationsKeepIndependentState() throws {
        let interpreter = try KeyboardInterpreter()
        let first = keyboardDevice(generation: 1)
        let second = keyboardDevice(generation: 2)

        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: first,
                kind: .keymap(
                    keymapPayload(
                        text: try fixtureKeymapText(), keyboardGeneration: first.generation))
            )
        )
        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: second,
                kind: .keymap(
                    keymapPayload(
                        text: try fixtureKeymapText(), keyboardGeneration: second.generation))
            ))

        let oldDeviceKey = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: first, kind: .key(qKey())))
                .first
        )
        let newDeviceKey = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: second, kind: .key(qKey())))
                .first
        )

        #expect(oldDeviceKey.interpretedKey?.keysymName == "q")
        #expect(newDeviceKey.interpretedKey?.keysymName == "q")
        #expect(interpreter.trackedDeviceIDs == [first, second])
    }

    @Test
    func nonKeyboardRawEventsReturnEmptyArray() throws {
        let interpreter = try KeyboardInterpreter()
        let event = RawInputEvent(
            sequence: 1,
            seatID: RawSeatID(rawValue: 1),
            deviceID: nil,
            kind: .pointer(
                .motion(
                    RawPointerMotion(
                        time: 10,
                        x: WaylandFixed(rawValue: 0),
                        y: WaylandFixed(rawValue: 0)
                    )
                )
            )
        )

        #expect(interpreter.consume(event).isEmpty)
    }
}
