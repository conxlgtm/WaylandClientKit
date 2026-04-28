import Testing
import WaylandKeyboardInterpretation
import WaylandRaw

@testable import WaylandClient

@Suite
struct InterpretedKeyboardInputRouterTests {
    @Test
    func interpretedKeyRoutesToFocusedKeyboardWindow() {
        let router = focusedKeyboardRouter()

        let routed = router.route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(
                    InterpretedKeyboardKey(
                        serial: 10,
                        time: 11,
                        evdevKeycode: 16,
                        xkbKeycode: 24,
                        state: .pressed,
                        keysym: WaylandKeyboardInterpretation.KeyboardKeysym(rawValue: 0x71),
                        keysymName: "q",
                        utf8: "q",
                        repeats: true
                    )
                )
            )
        )

        #expect(routed.first?.windowID == WindowID(rawValue: 150))
        #expect(routed.first?.kind == .keyboard(.interpreted(.key(expectedInterpretedQKey()))))
    }

    @Test
    func interpretedKeymapRemainsSeatLevel() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .keymap(
                    InterpretedKeyboardKeymap(
                        id: RawKeyboardKeymapID(
                            seatID: RawSeatID(rawValue: 15),
                            keyboardGeneration: 1,
                            keymapGeneration: 1
                        ),
                        format: .xkbV1,
                        size: 1_024
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .keymap(InterpretedKeyboardKeymapInfo(format: .xkbV1, size: 1_024))
                    )
                )
        )
    }

    @Test
    func interpretedModifiersRemainSeatLevel() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 3,
                seatID: RawSeatID(rawValue: 15),
                kind: .modifiers(
                    InterpretedKeyboardModifiers(
                        serial: 20,
                        depressed: 1,
                        latched: 2,
                        locked: 3,
                        group: 4,
                        changedComponents: [.modsDepressed, .layoutEffective]
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(routed.first?.kind == .keyboard(.interpreted(.modifiers(expectedModifiers()))))
    }

    @Test
    func interpretedRepeatInfoRemainsSeatLevel() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 4,
                seatID: RawSeatID(rawValue: 15),
                kind: .repeatInfo(
                    InterpretedKeyboardRepeatInfo(rate: 30, delay: 400)
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .repeatInfo(
                            WaylandClient.InterpretedKeyboardRepeatInfo(rate: 30, delay: 400)
                        )
                    )
                )
        )
    }

    @Test
    func interpretedDiagnosticsRemainSeatLevel() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .unavailable(
                    WaylandKeyboardInterpretation.KeyboardInterpretationUnavailable(
                        reason: .missingKeymap
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .missingKeymap
                            )
                        )
                    )
                )
        )
    }
}

private func focusedKeyboardRouter() -> InputRouter {
    let router = InputRouter()
    let seatID = RawSeatID(rawValue: 15)
    router.register(windowID: WindowID(rawValue: 150), surfaceID: 1_500)
    _ = router.route(rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_500))
    return router
}

private func expectedInterpretedQKey() -> InterpretedKeyboardKeyEvent {
    InterpretedKeyboardKeyEvent(
        serial: 10,
        time: 11,
        rawKeycode: 16,
        xkbKeycode: 24,
        state: .pressed,
        keysym: WaylandClient.KeyboardKeysym(rawValue: 0x71),
        keysymName: "q",
        utf8: "q",
        repeats: true
    )
}

private func expectedModifiers() -> WaylandClient.InterpretedKeyboardModifiers {
    WaylandClient.InterpretedKeyboardModifiers(
        serial: 20,
        depressed: 1,
        latched: 2,
        locked: 3,
        group: 4,
        changedComponents: [.modsDepressed, .layoutEffective]
    )
}
