import Testing
import WaylandRaw

@testable import WaylandKeyboardInterpretation

@Suite
struct KeyboardInterpreterKeyEventTests {
    @Test
    func interpreterCreatesContext() throws {
        _ = try KeyboardInterpreter()
    }

    @Test
    func pressedKeyPreservesEvdevKeycodeAndInterpretsSymbolTextAndRepeat() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()), sequence: 2)
            )
            .first
        )
        let key = try #require(event.interpretedKey)

        #expect(event.sequence == 2)
        #expect(key.evdevKeycode == 16)
        #expect(key.xkbKeycode == 24)
        #expect(key.state == .pressed)
        #expect(key.keysymName == "q")
        #expect(key.utf8 == "q")
        #expect(key.repeats)
    }

    @Test
    func repeatedKeyPreservesRepeatedState() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: .repeated))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .repeated)
        #expect(key.utf8 == "q")
        #expect(key.repeats)
    }

    @Test
    func releasedKeyPreservesSymbolButDoesNotProduceText() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: .released))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .released)
        #expect(key.keysymName == "q")
        #expect(key.utf8 == nil)
        #expect(!key.repeats)
        #expect(key.interpretation == .released(keysymName: "q"))
    }

    @Test
    func unknownKeyStatePreservesStateWithoutTextOrRepeatPayload() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let unknownState = RawKeyboardKeyState(rawValue: 99)
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: unknownState))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)
        let interpretedState = InterpretedKeyboardKeyState(rawValue: 99)

        #expect(key.state == interpretedState)
        #expect(key.keysymName == "q")
        #expect(key.utf8 == nil)
        #expect(!key.repeats)
        #expect(key.interpretation == .unknown(state: interpretedState, keysymName: "q"))
    }

    @Test
    func evdevKeycodeOverflowProducesInvalidKeycodeDiagnostic() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(evdevKeycode: UInt32.max))
                )
            ).first
        )

        #expect(event.kind == unavailable(.invalidKeycode(UInt32.max)))
    }

    @Test
    func modifierEventUpdatesStateAndReportsChangedComponents() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let shiftMask = try #require(
            KeyboardLayoutState(keymap: try keymapPayload(text: try fixtureKeymapText()))
                .modifierMask(named: "Shift"))
        let modifiers = RawKeyboardModifiers(
            serial: 9,
            depressed: shiftMask,
            latched: 0,
            locked: 0,
            group: 0
        )
        let modifierEvent = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .modifiers(modifiers))
            )
            .first
        )
        let interpretedModifiers = try #require(modifierEvent.interpretedModifiers)

        #expect(interpretedModifiers.serial == 9)
        #expect(interpretedModifiers.depressed == shiftMask)
        #expect(interpretedModifiers.changedComponents.contains(.modsDepressed))
        #expect(interpretedModifiers.changedComponents.contains(.modsEffective))

        let keyEvent = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey())))
                .first
        )
        #expect(keyEvent.interpretedKey?.keysymName == "Q")
        #expect(keyEvent.interpretedKey?.utf8 == "Q")
    }

    @Test
    func modifiersBeforeKeymapProduceMissingStateDiagnostic() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .modifiers(
                        RawKeyboardModifiers(
                            serial: 1,
                            depressed: 0,
                            latched: 0,
                            locked: 0,
                            group: 0
                        )
                    )
                )
            ).first
        )

        #expect(event.kind == unavailable(.missingKeyboardState))
    }

    @Test
    func repeatInfoIsStoredAndEmittedWithoutSynthesizingEvents() throws {
        let interpreter = try KeyboardInterpreter()
        let deviceID = keyboardDevice()
        let repeatInfo = RawKeyboardRepeatInfo(rate: 30, delay: 400)
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .repeatInfo(repeatInfo)
                )
            ).first
        )

        #expect(event.kind == .repeatInfo(InterpretedKeyboardRepeatInfo(rate: 30, delay: 400)))
        #expect(interpreter.repeatInfo(for: deviceID) == repeatInfo)
    }

    @Test
    func interpretedPayloadsAreSendableValues() {
        requireSendable(InterpretedKeyboardEvent.self)
        requireSendable(InterpretedKeyboardEventKind.self)
        requireSendable(InterpretedKeyboardKey.self)
        requireSendable(InterpretedKeyboardKeyInterpretation.self)
        requireSendable(InterpretedKeyboardKeyState.self)
        requireSendable(InterpretedKeyboardModifiers.self)
        requireSendable(KeyboardInterpretationUnavailable.self)
    }
}
