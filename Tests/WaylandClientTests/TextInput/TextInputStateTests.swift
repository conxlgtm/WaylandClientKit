import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct TextInputStateTests {
    @Test
    func pendingStateBuildsOneCompleteTransaction() {
        let hint = TextInputPreeditHint(start: 1, end: 3, kind: .spellingError)
        var pending = PendingTextInputTransaction()
        pending.preedit = RawTextInputPreedit(
            text: "compose",
            cursorBegin: 2,
            cursorEnd: 4
        )
        pending.preeditHints = [hint]
        pending.deletion = TextInputDeletion(beforeLength: 5, afterLength: 6)
        pending.committedText = "é"
        pending.action = TextInputActionEvent(action: .submit, serial: 7)

        #expect(
            pending.transaction(
                seatID: SeatID(rawValue: 12),
                target: .unmanagedSurface,
                serial: TextInputCommitSerial(rawValue: 99),
                matchesLatestCommit: false
            )
                == TextInputTransaction(
                    seatID: SeatID(rawValue: 12),
                    target: .unmanagedSurface,
                    serial: TextInputCommitSerial(rawValue: 99),
                    matchesLatestCommit: false,
                    preedit: TextInputPreedit(
                        text: "compose",
                        cursorBegin: 2,
                        cursorEnd: 4,
                        hints: [hint]
                    ),
                    deletion: TextInputDeletion(beforeLength: 5, afterLength: 6),
                    committedText: "é",
                    action: TextInputActionEvent(action: .submit, serial: 7)
                )
        )
    }

    @Test
    func resetClearsEveryPendingTransactionPayload() {
        var pending = PendingTextInputTransaction()
        pending.preedit = RawTextInputPreedit(
            text: "discarded",
            cursorBegin: 0,
            cursorEnd: 1
        )
        pending.preeditHints = [
            TextInputPreeditHint(start: 0, end: 1, kind: .prediction)
        ]
        pending.deletion = TextInputDeletion(beforeLength: 2, afterLength: 3)
        pending.committedText = "discarded"
        pending.action = TextInputActionEvent(
            action: TextInputAction(rawValue: 777),
            serial: 8
        )

        pending.reset()

        #expect(
            pending.transaction(
                seatID: SeatID(rawValue: 13),
                target: .focusless,
                serial: TextInputCommitSerial(rawValue: 0),
                matchesLatestCommit: true
            )
                == TextInputTransaction(
                    seatID: SeatID(rawValue: 13),
                    target: .focusless,
                    serial: TextInputCommitSerial(rawValue: 0),
                    matchesLatestCommit: true,
                    preedit: nil,
                    deletion: nil,
                    committedText: nil,
                    action: nil
                )
        )
    }
}
