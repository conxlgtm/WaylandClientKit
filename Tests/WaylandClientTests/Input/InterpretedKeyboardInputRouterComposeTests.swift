import Testing
import WaylandKeyboard
import WaylandRaw

@testable import WaylandClient

@Suite
struct InterpretedKeyboardInputRouterComposeTests {
    @Test
    func interpretedKeyTextResultMapsToClientDomain() throws {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(interpretedComposeAKey())
            )
        )
        let key = try #require(interpretedKeyboardKey(from: routed.first))

        #expect(routed.first?.target == .surface(.window(WindowID(rawValue: 150))))
        #expect(key.keySymbols == [WaylandClient.KeyboardKeysym(rawValue: 0x61)])
        #expect(key.primaryKeySymbol == WaylandClient.KeyboardKeysym(rawValue: 0x61))
        #expect(
            key.text
                == WaylandClient.KeyboardTextResult.committed(
                    WaylandClient.KeyboardTextCommit(
                        string: "á",
                        source: .compose,
                        resultKeysym: WaylandClient.KeyboardKeysym(rawValue: 0xE1),
                        resultKeysymName: "aacute"
                    )
                ))
    }

    @Test
    func inputRouterMapsComposingTextResult() throws {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(
                    interpretedComposeAKey(
                        text: .composing(
                            WaylandKeyboard.KeyboardComposeProgress(
                                startedBy: WaylandKeyboard.KeyboardKeysym(
                                    rawValue: 0xFE51
                                ),
                                startedByName: "dead_acute"
                            )
                        )
                    )
                )
            )
        )
        let key = try #require(interpretedKeyboardKey(from: routed.first))

        #expect(
            key.text
                == WaylandClient.KeyboardTextResult.composing(
                    WaylandClient.KeyboardComposeProgress(
                        startedBy: WaylandClient.KeyboardKeysym(rawValue: 0xFE51),
                        startedByName: "dead_acute"
                    )
                ))
    }

    @Test
    func inputRouterMapsCancelledTextResult() throws {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 3,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(
                    interpretedComposeAKey(
                        text: .cancelled(
                            WaylandKeyboard.KeyboardComposeCancellation(
                                cancellingKeysym:
                                    WaylandKeyboard.KeyboardKeysym(rawValue: 0x62),
                                cancellingKeysymName: "b",
                                fallbackCommit:
                                    WaylandKeyboard.KeyboardTextCommit(
                                        string: "b",
                                        source: .composeCancellationFallback,
                                        resultKeysym:
                                            WaylandKeyboard.KeyboardKeysym(
                                                rawValue: 0x62
                                            ),
                                        resultKeysymName: "b"
                                    )
                            )
                        )
                    )
                )
            )
        )
        let key = try #require(interpretedKeyboardKey(from: routed.first))

        #expect(
            key.text
                == WaylandClient.KeyboardTextResult.cancelled(
                    WaylandClient.KeyboardComposeCancellation(
                        cancellingKeysym: WaylandClient.KeyboardKeysym(rawValue: 0x62),
                        cancellingKeysymName: "b",
                        fallbackCommit: WaylandClient.KeyboardTextCommit(
                            string: "b",
                            source: .composeCancellationFallback,
                            resultKeysym: WaylandClient.KeyboardKeysym(rawValue: 0x62),
                            resultKeysymName: "b"
                        )
                    )
                ))
    }

    @Test
    func publicRouterMapsMultiStepComposeProgress() throws {
        let routed = focusedKeyboardRouter().route(
            interpretedKeyboardEvent(
                sequence: 2,
                seatID: RawSeatID(rawValue: 15),
                kind: .key(
                    interpretedComposeAKey(
                        text: .composing(
                            WaylandKeyboard.KeyboardComposeProgress(
                                startedBy: WaylandKeyboard.KeyboardKeysym(
                                    rawValue: 0xFE51
                                ),
                                startedByName: "dead_acute"
                            )
                        ),
                        keysym: WaylandKeyboard.KeyboardKeysym(rawValue: 0x62)
                    )
                )
            )
        )
        let key = try #require(interpretedKeyboardKey(from: routed.first))

        #expect(key.keysym == WaylandClient.KeyboardKeysym(rawValue: 0x62))
        #expect(
            key.text
                == WaylandClient.KeyboardTextResult.composing(
                    WaylandClient.KeyboardComposeProgress(
                        startedBy: WaylandClient.KeyboardKeysym(rawValue: 0xFE51),
                        startedByName: "dead_acute"
                    )
                ))
    }

    @Test
    func interpretedComposeFailureReasonRemainsTyped() {
        let router = focusedKeyboardRouter()
        let routed = router.route(
            unavailableKeyboardEvent(.composeTableUnavailable(locale: "zz_ZZ.UTF-8"))
        )
        let emptyBufferRouted = router.route(
            unavailableKeyboardEvent(.emptyComposeTableBuffer)
        )

        #expect(routed.first?.target == .display)
        #expect(
            routed.first?.kind
                == .keyboard(
                    .interpreted(
                        WaylandClient.InterpretedKeyboardEvent.unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .composeTableUnavailable(locale: "zz_ZZ.UTF-8")
                            )
                        )
                    )
                )
        )
        #expect(
            emptyBufferRouted.first?.kind
                == .keyboard(
                    .interpreted(
                        WaylandClient.InterpretedKeyboardEvent.unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .invalidComposeConfiguration
                            )
                        )
                    )
                )
        )
    }
}

private func unavailableKeyboardEvent(
    _ reason: WaylandKeyboard.KeyboardInterpretationUnavailableReason
) -> WaylandKeyboard.InterpretedKeyboardEvent {
    interpretedKeyboardEvent(
        sequence: 2,
        seatID: RawSeatID(rawValue: 15),
        kind: .unavailable(
            WaylandKeyboard.KeyboardInterpretationUnavailable(reason: reason)
        )
    )
}

private func interpretedComposeAKey() -> InterpretedKeyboardKey {
    interpretedComposeAKey(
        text: .committed(
            WaylandKeyboard.KeyboardTextCommit(
                string: "á",
                source: .compose,
                resultKeysym: WaylandKeyboard.KeyboardKeysym(rawValue: 0xE1),
                resultKeysymName: "aacute"
            )
        )
    )
}

private func interpretedComposeAKey(
    text: WaylandKeyboard.KeyboardTextResult,
    keysym: WaylandKeyboard.KeyboardKeysym =
        WaylandKeyboard.KeyboardKeysym(rawValue: 0x61)
) -> InterpretedKeyboardKey {
    InterpretedKeyboardKey(
        serial: 10,
        time: 11,
        evdevKeycode: 30,
        xkbKeycode: 38,
        symbolResolution: .single(keysym),
        interpretation: .pressed(
            keysymName: keysym.rawValue == 0x62 ? "b" : "a",
            utf8: keysym.rawValue == 0x62 ? "b" : "a",
            repeatCapability: .repeating
        ),
        text: text
    )
}

private func interpretedKeyboardKey(from event: InputEvent?) -> InterpretedKeyboardKeyEvent? {
    guard case .keyboard(.interpreted(.key(let key))) = event?.kind else {
        return nil
    }

    return key
}
