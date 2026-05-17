import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct TextInputStateTests {
    @Test
    func donePublishesBufferedTransactionInProtocolOrder() {
        let seatID = SeatID(rawValue: 12)
        let hint = TextInputPreeditHint(
            start: 1,
            end: 3,
            kind: .spellingError
        )
        var state = TextInputState(seatID: seatID)

        #expect(state.reduce(.preeditHint(hint)).isEmpty)
        #expect(
            state.reduce(
                .preeditString(
                    RawTextInputPreedit(
                        text: "compose",
                        cursorBegin: 2,
                        cursorEnd: 4
                    )
                )
            ).isEmpty
        )
        #expect(
            state.reduce(
                .deleteSurroundingText(beforeLength: 5, afterLength: 6)
            ).isEmpty
        )
        #expect(state.reduce(.commitString("é")).isEmpty)
        #expect(
            state.reduce(
                .action(action: .submit, serial: 44)
            ).isEmpty
        )

        let events = state.reduce(.done(serial: 99))

        #expect(
            events == [
                .preedit(
                    TextInputPreeditEvent(
                        seatID: seatID,
                        text: "compose",
                        cursorBegin: 2,
                        cursorEnd: 4,
                        hints: [hint]
                    )
                ),
                .deleteSurroundingText(
                    TextInputDeleteSurroundingTextEvent(
                        seatID: seatID,
                        beforeLength: 5,
                        afterLength: 6
                    )
                ),
                .committed(TextInputCommitEvent(seatID: seatID, text: "é")),
                .action(
                    TextInputActionEvent(
                        seatID: seatID,
                        action: .submit,
                        serial: 44
                    )
                ),
                .done(TextInputDoneEvent(seatID: seatID, serial: 99)),
            ]
        )
    }

    @Test
    func enterAndLeaveResetPendingTransaction() {
        let seatID = SeatID(rawValue: 4)
        var state = TextInputState(seatID: seatID)

        _ = state.reduce(.commitString("discarded"))
        #expect(
            state.reduce(.enter(.surface(.window(WindowID(rawValue: 7)))))
                == [
                    .entered(
                        TextInputFocusEvent(
                            seatID: seatID,
                            target: .surface(.window(WindowID(rawValue: 7)))
                        )
                    )
                ]
        )
        #expect(
            state.reduce(.done(serial: 1))
                == [.done(TextInputDoneEvent(seatID: seatID, serial: 1))]
        )

        _ = state.reduce(.commitString("discarded"))
        #expect(
            state.reduce(.leave(.unmanagedSurface))
                == [
                    .left(
                        TextInputFocusEvent(
                            seatID: seatID,
                            target: .unmanagedSurface
                        )
                    )
                ]
        )
        #expect(
            state.reduce(.done(serial: 2))
                == [.done(TextInputDoneEvent(seatID: seatID, serial: 2))]
        )
    }

    @Test
    func languagePublishesKnownTagOutsideDoneTransaction() {
        let seatID = SeatID(rawValue: 5)
        var state = TextInputState(seatID: seatID)

        #expect(
            state.reduce(.language(.tag("fr-CA")))
                == [
                    .language(
                        TextInputLanguageEvent(
                            seatID: seatID,
                            language: .tag("fr-CA")
                        )
                    )
                ]
        )
    }

    @Test
    func languagePublishesUnknownResetOutsideDoneTransaction() {
        let seatID = SeatID(rawValue: 6)
        var state = TextInputState(seatID: seatID)

        #expect(
            state.reduce(.language(.unknown))
                == [
                    .language(
                        TextInputLanguageEvent(
                            seatID: seatID,
                            language: .unknown
                        )
                    )
                ]
        )
    }

    @Test
    func unknownActionAndHintRawValuesSurviveDoneTransaction() {
        let seatID = SeatID(rawValue: 7)
        let unknownAction = TextInputAction(rawValue: 99)
        let unknownHint = TextInputPreeditHint(
            start: 2,
            end: 5,
            kind: TextInputPreeditHintKind(rawValue: 777)
        )
        var state = TextInputState(seatID: seatID)

        #expect(state.reduce(.preeditHint(unknownHint)).isEmpty)
        #expect(
            state.reduce(
                .preeditString(
                    RawTextInputPreedit(
                        text: "prediction",
                        cursorBegin: 2,
                        cursorEnd: 5
                    )
                )
            ).isEmpty
        )
        #expect(state.reduce(.action(action: unknownAction, serial: 12)).isEmpty)

        #expect(
            state.reduce(.done(serial: 13))
                == [
                    .preedit(
                        TextInputPreeditEvent(
                            seatID: seatID,
                            text: "prediction",
                            cursorBegin: 2,
                            cursorEnd: 5,
                            hints: [unknownHint]
                        )
                    ),
                    .action(
                        TextInputActionEvent(
                            seatID: seatID,
                            action: unknownAction,
                            serial: 12
                        )
                    ),
                    .done(TextInputDoneEvent(seatID: seatID, serial: 13)),
                ]
        )
    }
}
