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
                        keysym: WaylandKeyboardInterpretation.KeyboardKeysym(rawValue: 0x71),
                        interpretation: .pressed(
                            keysymName: "q",
                            utf8: "q",
                            repeatCapability: .repeating
                        )
                    )
                )
            )
        )

        #expect(routed.first?.target == .surface(.window(WindowID(rawValue: 150))))
        #expect(routed.first?.kind == .keyboard(.interpreted(.key(expectedInterpretedQKey()))))
    }

    @Test
    func interpretedKeyAfterUnknownSurfaceEnterStaysUnmanagedSurface() {
        let router = unmanagedSurfaceFocusedKeyboardRouter()

        let routed = router.route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 16),
                kind: .key(
                    InterpretedKeyboardKey(
                        serial: 10,
                        time: 11,
                        evdevKeycode: 16,
                        xkbKeycode: 24,
                        keysym: WaylandKeyboardInterpretation.KeyboardKeysym(rawValue: 0x71),
                        interpretation: .pressed(
                            keysymName: "q",
                            utf8: "q",
                            repeatCapability: .repeating
                        )
                    )
                )
            )
        )

        #expect(routed.first?.windowID == nil)
        #expect(routed.first?.target == .unmanagedSurface)
        #expect(routed.first?.kind == .keyboard(.interpreted(.key(expectedInterpretedQKey()))))
    }

    @Test
    func interpretedKeyRepeatCapabilityMapsToClientDomain() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(
                    InterpretedKeyboardKey(
                        serial: 10,
                        time: 11,
                        evdevKeycode: 16,
                        xkbKeycode: 24,
                        keysym: WaylandKeyboardInterpretation.KeyboardKeysym(rawValue: 0x71),
                        interpretation: .pressed(
                            keysymName: "q",
                            utf8: "q",
                            repeatCapability: .nonRepeating
                        )
                    )
                )
            )
        )

        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .key(expectedInterpretedQKey(repeatCapability: .nonRepeating))
                    )
                )
        )
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

        #expect(routed.first?.target == .display)
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

        #expect(routed.first?.target == .display)
        #expect(routed.first?.kind == .keyboard(.interpreted(.modifiers(expectedModifiers()))))
    }

    @Test
    func interpretedRepeatInfoRemainsSeatLevel() throws {
        let rawRepeatInfo = try RawKeyboardRepeatInfo(rate: 30, delay: 400)
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 4,
                seatID: RawSeatID(rawValue: 15),
                kind: .repeatInfo(
                    InterpretedKeyboardRepeatInfo(rawRepeatInfo)
                )
            )
        )

        #expect(routed.first?.target == .display)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .repeatInfo(
                            try KeyboardRepeatPolicy(rate: 30, delay: 400)
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

        #expect(routed.first?.target == .display)
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

    @Test
    func interpretedKeymapReadFailureReasonRemainsTyped() {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .unavailable(
                    WaylandKeyboardInterpretation.KeyboardInterpretationUnavailable(
                        reason: .keymapReadFailed(.missingNULTerminator(size: 12))
                    )
                )
            )
        )

        #expect(routed.first?.target == .display)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        .unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .keymapReadFailed(.missingNULTerminator(size: 12))
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

private func unmanagedSurfaceFocusedKeyboardRouter() -> InputRouter {
    let router = InputRouter()
    let seatID = RawSeatID(rawValue: 16)
    _ = router.route(rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_600))
    return router
}

private func expectedInterpretedQKey(
    repeatCapability: WaylandClient.KeyboardKeyRepeatCapability = .repeating
) -> InterpretedKeyboardKeyEvent {
    InterpretedKeyboardKeyEvent(
        serial: 10,
        time: 11,
        rawKeycode: 16,
        xkbKeycode: 24,
        keysym: WaylandClient.KeyboardKeysym(rawValue: 0x71),
        interpretation: .pressed(
            keysymName: "q",
            utf8: "q",
            repeatCapability: repeatCapability
        )
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
