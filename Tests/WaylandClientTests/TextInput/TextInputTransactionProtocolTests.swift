import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct TextInputTransactionProtocolTests {
    @Test
    func commitsReturnMonotonicSerials() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 20)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 37))

        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 1))
        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 2))
        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 3))
    }

    @Test
    func commitSerialWrapsFromMaximumToZero() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(
            backend: backend,
            initialCommitSerial: TextInputCommitSerial(rawValue: UInt32.max - 1)
        )
        let seatID = SeatID(rawValue: 21)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 38))

        #expect(
            try manager.commit(seatID: seatID)
                == TextInputCommitSerial(rawValue: UInt32.max)
        )
        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 0))
    }

    @Test
    func enterBeforeEnablePreservesCurrentFocusedTarget() throws {
        let backend = RecordingTextInputBackend()
        let seatID = SeatID(rawValue: 11)
        let windowID = WindowID(rawValue: 21)
        let manager = TextInputManager(backend: backend) { surfaceID in
            surfaceID == RawObjectID(42)
                ? .surface(.window(windowID))
                : .unmanagedSurface
        }

        try manager.prepareSession(for: seatID)
        backend.emit(.enter(surfaceID: RawObjectID(42)), seatID: seatID)
        try manager.enable(seatID: seatID, windowID: windowID)
        let serial = try manager.commit(seatID: seatID)
        backend.emit(.commitString("text"), seatID: seatID)
        backend.emit(.done(serial: serial.rawValue), seatID: seatID)

        #expect(
            manager.drainEvents() == [
                .entered(
                    TextInputFocusEvent(
                        seatID: seatID,
                        target: .surface(.window(windowID))
                    )
                ),
                .transaction(
                    TextInputTransaction(
                        seatID: seatID,
                        target: .surface(.window(windowID)),
                        serial: serial,
                        matchesLatestCommit: true,
                        preedit: nil,
                        deletion: nil,
                        committedText: "text",
                        action: nil
                    )
                ),
            ]
        )
    }

    @Test
    func staleTransactionPublishesAllCompositorChanges() throws {
        let backend = RecordingTextInputBackend()
        let seatID = SeatID(rawValue: 22)
        let windowID = WindowID(rawValue: 39)
        let manager = TextInputManager(backend: backend) { _ in
            .surface(.window(windowID))
        }

        try manager.enable(seatID: seatID, windowID: windowID)
        let staleSerial = try manager.commit(seatID: seatID)
        _ = try manager.commit(seatID: seatID)
        backend.emit(.enter(surfaceID: RawObjectID(43)), seatID: seatID)
        backend.emit(
            .preeditString(
                RawTextInputPreedit(text: "compose", cursorBegin: 1, cursorEnd: 3)
            ),
            seatID: seatID
        )
        backend.emit(
            .deleteSurroundingText(beforeLength: 4, afterLength: 5),
            seatID: seatID
        )
        backend.emit(.commitString("committed"), seatID: seatID)
        backend.emit(
            .action(RawTextInputActionEvent(action: .submit, serial: 99)),
            seatID: seatID
        )
        backend.emit(.done(serial: staleSerial.rawValue), seatID: seatID)

        let events = manager.drainEvents()
        #expect(events.count == 2)
        guard case .transaction(let transaction)? = events.last else {
            Issue.record("expected completed text-input transaction")
            return
        }
        #expect(transaction.seatID == seatID)
        #expect(transaction.target == .surface(.window(windowID)))
        #expect(transaction.serial == staleSerial)
        #expect(!transaction.matchesLatestCommit)
        #expect(
            transaction.preedit
                == TextInputPreedit(
                    text: "compose",
                    cursorBegin: 1,
                    cursorEnd: 3,
                    hints: []
                )
        )
        #expect(
            transaction.deletion
                == TextInputDeletion(beforeLength: 4, afterLength: 5)
        )
        #expect(transaction.committedText == "committed")
        #expect(
            transaction.action
                == TextInputActionEvent(action: .submit, serial: 99)
        )
    }

    @Test
    func leaveResetsPendingTransactionContents() throws {
        let backend = RecordingTextInputBackend()
        let seatID = SeatID(rawValue: 23)
        let windowID = WindowID(rawValue: 40)
        let manager = TextInputManager(backend: backend) { _ in
            .surface(.window(windowID))
        }

        try manager.enable(seatID: seatID, windowID: windowID)
        let serial = try manager.commit(seatID: seatID)
        backend.emit(.enter(surfaceID: RawObjectID(44)), seatID: seatID)
        backend.emit(.commitString("discarded"), seatID: seatID)
        backend.emit(
            .deleteSurroundingText(beforeLength: 1, afterLength: 2),
            seatID: seatID
        )
        backend.emit(.leave(surfaceID: RawObjectID(44)), seatID: seatID)
        backend.emit(.done(serial: serial.rawValue), seatID: seatID)

        guard case .transaction(let transaction) = manager.drainEvents().last else {
            Issue.record("expected completed text-input transaction")
            return
        }
        #expect(transaction.target == .focusless)
        #expect(transaction.preedit == nil)
        #expect(transaction.deletion == nil)
        #expect(transaction.committedText == nil)
        #expect(transaction.action == nil)
    }

    @Test
    func enableResetsPendingTransactionContents() throws {
        let backend = RecordingTextInputBackend()
        let seatID = SeatID(rawValue: 24)
        let windowID = WindowID(rawValue: 41)
        let manager = TextInputManager(backend: backend) { _ in
            .surface(.window(windowID))
        }

        try manager.enable(seatID: seatID, windowID: windowID)
        _ = try manager.commit(seatID: seatID)
        backend.emit(.enter(surfaceID: RawObjectID(45)), seatID: seatID)
        backend.emit(
            .preeditString(
                RawTextInputPreedit(text: "discarded", cursorBegin: 1, cursorEnd: 2)
            ),
            seatID: seatID
        )
        backend.emit(
            .deleteSurroundingText(beforeLength: 3, afterLength: 4),
            seatID: seatID
        )
        backend.emit(.commitString("discarded"), seatID: seatID)
        backend.emit(
            .action(RawTextInputActionEvent(action: .submit, serial: 5)),
            seatID: seatID
        )

        try manager.enable(seatID: seatID, windowID: windowID)
        let serial = try manager.commit(seatID: seatID)
        backend.emit(.done(serial: serial.rawValue), seatID: seatID)

        guard case .transaction(let transaction) = manager.drainEvents().last else {
            Issue.record("expected completed text-input transaction")
            return
        }
        #expect(transaction.target == .surface(.window(windowID)))
        #expect(transaction.matchesLatestCommit)
        #expect(transaction.preedit == nil)
        #expect(transaction.deletion == nil)
        #expect(transaction.committedText == nil)
        #expect(transaction.action == nil)
    }
}
