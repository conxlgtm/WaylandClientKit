import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct TextInputManagerTests {
    @Test
    func prepareSessionBindsSeatOnce() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 8)

        try manager.prepareSession(for: seatID)
        try manager.prepareSession(for: seatID)

        #expect(backend.boundSeatIDs == [seatID])
    }

    @Test
    func requestsForwardToSeatBinding() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 9)
        let text = "Aé"
        let rect = try LogicalRect(x: 1, y: 2, width: 3, height: 4)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 3))
        try manager.setSurroundingText(
            TextInputSurroundingText(
                text: text,
                cursorUTF8Offset: 3,
                anchorUTF8Offset: 1
            ),
            seatID: seatID
        )
        try manager.setTextChangeCause(.other, seatID: seatID)
        try manager.setContentType(
            hints: [.completion, .spellcheck],
            purpose: .email,
            seatID: seatID
        )
        try manager.setCursorRectangle(rect, seatID: seatID)
        try manager.commit(seatID: seatID)
        try manager.disable(seatID: seatID)

        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .setSurroundingText(text, cursor: 3, anchor: 1),
                .setTextChangeCause(.other),
                .setContentType(hints: [.completion, .spellcheck], purpose: .email),
                .setCursorRectangle(rect),
                .commit,
                .disable,
            ]
        )
    }

    @Test
    func requestBeforeEnableThrowsInactiveSessionAndPublishesDiagnostic() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 14)

        try manager.prepareSession(for: seatID)

        #expect(
            throws: TextInputError.inactiveSession(
                seatID: seatID,
                operation: .commit
            )
        ) {
            try manager.commit(seatID: seatID)
        }
        #expect(backend.binding(for: seatID)?.operations.isEmpty == true)
        #expect(
            manager.drainEvents() == [
                .diagnostic(
                    TextInputDiagnostic(
                        seatID: seatID,
                        operation: .invalidRequest(.commit),
                        message: "ignored text-input commit request in inactive"
                    )
                )
            ]
        )
    }

    @Test
    func repeatedDisableIsIdempotentAfterEnabledSession() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 15)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 31))
        try manager.disable(seatID: seatID)
        try manager.disable(seatID: seatID)

        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .disable,
            ]
        )
    }

    @Test
    func disableFinalizesSessionAndCommitAfterDisableIsInvalid() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 18)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 35))
        try manager.disable(seatID: seatID)

        #expect(
            throws: TextInputError.inactiveSession(
                seatID: seatID,
                operation: .commit
            )
        ) {
            try manager.commit(seatID: seatID)
        }
        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .disable,
            ]
        )
        #expect(
            manager.drainEvents() == [
                .diagnostic(
                    TextInputDiagnostic(
                        seatID: seatID,
                        operation: .invalidRequest(.commit),
                        message: "ignored text-input commit request in disabled"
                    )
                )
            ]
        )
    }

    @Test
    func removedSeatDestroysBindingAndPublishesDiagnostic() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 16)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 32))
        manager.removeSeat(seatID)

        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .destroy,
            ]
        )
        #expect(
            manager.drainEvents() == [
                .diagnostic(
                    TextInputDiagnostic(
                        seatID: seatID,
                        operation: .seatRemoved,
                        message: "text-input seat \(seatID) was removed"
                    )
                )
            ]
        )
        #expect(throws: TextInputError.unknownSeat(seatID)) {
            try manager.commit(seatID: seatID)
        }
    }

    @Test
    func lateRawEventsAfterSeatRemovalAreIgnored() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 17)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 34))
        manager.removeSeat(seatID)
        _ = manager.drainEvents()

        backend.emit(.commitString("late"), seatID: seatID)
        backend.emit(.done(serial: 1), seatID: seatID)

        #expect(manager.drainEvents().isEmpty)
        #expect(backend.boundSeatIDs == [seatID])
    }

    @Test
    func unavailableBackendErrorIsPreserved() {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 10)
        backend.failingSeatIDs.insert(seatID)

        #expect(throws: TextInputError.unavailable) {
            try manager.prepareSession(for: seatID)
        }
    }

    @Test
    func rawEventsPublishResolvedTargets() throws {
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
        backend.emit(.commitString("text"), seatID: seatID)
        backend.emit(.done(serial: 55), seatID: seatID)

        #expect(
            manager.drainEvents() == [
                .entered(
                    TextInputFocusEvent(
                        seatID: seatID,
                        target: .surface(.window(windowID))
                    )
                ),
                .committed(TextInputCommitEvent(seatID: seatID, text: "text")),
                .done(TextInputDoneEvent(seatID: seatID, serial: 55)),
            ]
        )
    }

    @Test
    func rawLanguageEventsNormalizeEmptyAndNilToUnknown() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 13)

        try manager.prepareSession(for: seatID)
        backend.emit(.language("en-US"), seatID: seatID)
        backend.emit(.language(""), seatID: seatID)
        backend.emit(.language(nil), seatID: seatID)

        #expect(
            manager.drainEvents() == [
                .language(
                    TextInputLanguageEvent(
                        seatID: seatID,
                        language: .tag("en-US")
                    )
                ),
                .language(
                    TextInputLanguageEvent(seatID: seatID, language: .unknown)
                ),
                .language(
                    TextInputLanguageEvent(seatID: seatID, language: .unknown)
                ),
            ]
        )
    }

    @Test
    func shutdownDestroysBindingsOnceAndIgnoresLateEvents() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 12)

        try manager.prepareSession(for: seatID)
        manager.shutdown()
        manager.shutdown()
        backend.emit(.commitString("late"), seatID: seatID)
        backend.emit(.done(serial: 1), seatID: seatID)

        #expect(backend.binding(for: seatID)?.operations == [.destroy])
        #expect(manager.drainEvents().isEmpty)
        #expect(throws: TextInputError.unavailable) {
            try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 33))
        }
    }
}

private final class RecordingTextInputBackend: TextInputManagerBackend {
    var boundSeatIDs: [SeatID] = []
    var failingSeatIDs: Set<SeatID> = []

    private var bindingsBySeatID: [SeatID: RecordingTextInputBinding] = [:]
    private var eventSinksBySeatID: [SeatID: (RawTextInputEvent) -> Void] = [:]

    func preconditionIsOwnerThread() {
        // Test backend has no thread-affinity boundary.
    }

    func bindTextInput(
        for seatID: SeatID,
        onEvent: @escaping (RawTextInputEvent) -> Void
    ) throws -> any TextInputBinding {
        boundSeatIDs.append(seatID)

        if failingSeatIDs.contains(seatID) {
            throw TextInputError.unavailable
        }

        let binding = RecordingTextInputBinding(seatID: seatID)
        bindingsBySeatID[seatID] = binding
        eventSinksBySeatID[seatID] = onEvent
        return binding
    }

    func binding(for seatID: SeatID) -> RecordingTextInputBinding? {
        bindingsBySeatID[seatID]
    }

    func emit(_ event: RawTextInputEvent, seatID: SeatID) {
        eventSinksBySeatID[seatID]?(event)
    }
}

private final class RecordingTextInputBinding: TextInputBinding {
    enum Operation: Equatable {
        case enable
        case disable
        case setSurroundingText(String, cursor: Int32, anchor: Int32)
        case setTextChangeCause(TextInputChangeCause)
        case setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose)
        case setCursorRectangle(LogicalRect)
        case commit
        case destroy
    }

    let seatID: SeatID
    private(set) var operations: [Operation] = []

    init(seatID bindingSeatID: SeatID) {
        seatID = bindingSeatID
    }

    func enable() {
        operations.append(.enable)
    }

    func disable() {
        operations.append(.disable)
    }

    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32) {
        operations.append(
            .setSurroundingText(text, cursor: cursor, anchor: anchor)
        )
    }

    func setTextChangeCause(_ cause: TextInputChangeCause) {
        operations.append(.setTextChangeCause(cause))
    }

    func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose
    ) {
        operations.append(.setContentType(hints: hints, purpose: purpose))
    }

    func setCursorRectangle(_ rect: LogicalRect) {
        operations.append(.setCursorRectangle(rect))
    }

    func commit() {
        operations.append(.commit)
    }

    func destroy() {
        operations.append(.destroy)
    }
}
