import Testing
import WaylandRaw

@testable import WaylandKeyboardInterpretation

@Suite
struct KeyboardInterpreterKeymapStateTests {
    @Test
    func validKeymapAfterUnavailableStateReinstallsLayout() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let invalidPayload = try keymapPayload(bytes: Array("not a keymap".utf8) + [0])
        let validPayload = try keymapPayload(text: try fixtureKeymapText(), keymapGeneration: 2)

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(invalidPayload))
        )
        #expect(
            interpreter.keymapState(for: deviceID)
                == .unavailable(keymapID: invalidPayload.id, reason: .invalidKeymap)
        )

        let keymapEvent = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .keymap(validPayload))
            )
            .first
        )

        #expect(
            keymapEvent.kind
                == .keymap(
                    InterpretedKeyboardKeymap(
                        id: validPayload.id,
                        format: .xkbV1,
                        size: validPayload.size
                    )
                )
        )
        #expect(interpreter.keymapID(for: deviceID) == validPayload.id)
        #expect(interpreter.keymapState(for: deviceID) == .valid(validPayload.id))
    }
}
