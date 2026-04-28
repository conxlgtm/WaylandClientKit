import Testing
import WaylandKeyboardInterpretation
import WaylandRaw

@testable import WaylandClient

@Suite
struct DisplaySessionInputPipelineTests {
    @Test
    func rawKeyboardEventPrecedesInterpretedDiagnosticFromSameRawEvent() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter()
        let seatID = RawSeatID(rawValue: 18)
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)
        let windowID = WindowID(rawValue: 180)
        router.register(windowID: windowID, surfaceID: 1_800)

        _ = routeSessionInputEvents(
            from: [rawKeyboardEnter(sequence: 1, seatID: seatID, surfaceID: 1_800)],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        let key = rawKeyboardKey(
            sequence: 2,
            seatID: seatID,
            serial: 12,
            time: 13,
            rawKeycode: 16,
            deviceID: deviceID
        )
        let routed = routeSessionInputEvents(
            from: [key],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        #expect(routed.count == 2)
        #expect(routed.map(\.sequence) == [2, 2])
        #expect(routed[0].windowID == windowID)
        #expect(routed[1].windowID == nil)
        #expect(
            routed[0].kind
                == .keyboard(
                    .raw(
                        .key(
                            KeyboardKeyEvent(
                                serial: 12,
                                time: 13,
                                rawKeycode: 16,
                                state: .pressed
                            )
                        )
                    )
                )
        )
        #expect(
            routed[1].kind
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
    func rawKeymapEventPrecedesInterpreterKeymapDiagnostic() throws {
        let router = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter()
        let seatID = RawSeatID(rawValue: 19)
        let deviceID = RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)

        let keymap = rawKeyboardKeymap(sequence: 1, seatID: seatID, deviceID: deviceID)
        let routed = routeSessionInputEvents(
            from: [keymap],
            inputRouter: router,
            keyboardInterpreter: keyboardInterpreter
        )

        #expect(routed.count == 2)
        #expect(routed.map(\.windowID) == [nil, nil])
        #expect(
            routed[0].kind
                == .keyboard(
                    .raw(.keymapChanged(KeyboardKeymapInfo(format: .xkbV1, size: 8)))
                )
        )
        #expect(
            routed[1].kind
                == .keyboard(
                    .interpreted(
                        .unavailable(
                            WaylandClient.KeyboardInterpretationUnavailable(
                                reason: .invalidKeymap
                            )
                        )
                    )
                )
        )
    }
}
