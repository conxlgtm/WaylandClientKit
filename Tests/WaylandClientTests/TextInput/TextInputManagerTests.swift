import Testing
import WaylandRaw

@testable import WaylandClient

// swiftlint:disable type_body_length
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
        try manager.showInputPanel(seatID: seatID)
        try manager.hideInputPanel(seatID: seatID)
        let commitSerial = try manager.commit(seatID: seatID)
        let disableSerial = try manager.disable(seatID: seatID)

        #expect(commitSerial == TextInputCommitSerial(rawValue: 1))
        #expect(disableSerial == TextInputCommitSerial(rawValue: 2))

        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .setSurroundingText(text, cursor: 3, anchor: 1),
                .setTextChangeCause(.other),
                .setContentType(hints: [.completion, .spellcheck], purpose: .email),
                .setCursorRectangle(rect),
                .showInputPanel,
                .hideInputPanel,
                .commit,
                .disable,
                .commit,
            ]
        )
    }

    @Test
    func inputPanelRequestsRequireVersionTwo() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 19)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 36))
        backend.binding(for: seatID)?.protocolVersion = 1

        #expect(
            throws: TextInputError.unsupportedVersion(
                operation: .showInputPanel,
                required: 2,
                available: 1
            )
        ) {
            try manager.showInputPanel(seatID: seatID)
        }
        #expect(
            throws: TextInputError.unsupportedVersion(
                operation: .hideInputPanel,
                required: 2,
                available: 1
            )
        ) {
            try manager.hideInputPanel(seatID: seatID)
        }
        #expect(backend.binding(for: seatID)?.operations == [.enable])
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
        let firstSerial = try manager.disable(seatID: seatID)
        let secondSerial = try manager.disable(seatID: seatID)

        #expect(firstSerial == TextInputCommitSerial(rawValue: 1))
        #expect(secondSerial == nil)
        #expect(
            backend.binding(for: seatID)?.operations == [
                .enable,
                .disable,
                .commit,
            ]
        )
    }

    @Test
    func disableFinalizesSessionAndCommitAfterDisableIsInvalid() throws {
        let backend = RecordingTextInputBackend()
        let manager = TextInputManager(backend: backend)
        let seatID = SeatID(rawValue: 18)

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 35))
        let binding = try #require(backend.binding(for: seatID))
        var lifecyclesDuringRequests: [TextInputSessionLifecycle] = []
        binding.onOperation = { operation in
            guard operation == .disable || operation == .commit else { return }
            lifecyclesDuringRequests.append(manager.lifecycle(for: seatID))
        }
        let serial = try manager.disable(seatID: seatID)
        binding.onOperation = nil

        #expect(serial == TextInputCommitSerial(rawValue: 1))
        #expect(
            lifecyclesDuringRequests == [
                .enabled(windowID: WindowID(rawValue: 35)),
                .enabled(windowID: WindowID(rawValue: 35)),
            ]
        )
        #expect(manager.lifecycle(for: seatID) == .disabled)
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
                .commit,
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
        let firstBinding = try #require(backend.binding(for: seatID))
        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 1))
        backend.emit(.commitString("discarded"), seatID: seatID)
        manager.removeSeat(seatID)

        #expect(
            firstBinding.operations == [
                .enable,
                .commit,
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

        try manager.enable(seatID: seatID, windowID: WindowID(rawValue: 32))
        #expect(backend.boundSeatIDs == [seatID, seatID])
        #expect(try manager.commit(seatID: seatID) == TextInputCommitSerial(rawValue: 1))
        backend.emit(.done(serial: 1), seatID: seatID)
        guard case .transaction(let transaction) = manager.drainEvents().last else {
            Issue.record("expected completed text-input transaction")
            return
        }
        #expect(transaction.committedText == nil)
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
// swiftlint:enable type_body_length

final class RecordingTextInputBackend: TextInputManagerBackend {
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

final class RecordingTextInputBinding: TextInputBinding {
    enum Operation: Equatable {
        case enable
        case disable
        case setSurroundingText(String, cursor: Int32, anchor: Int32)
        case setTextChangeCause(TextInputChangeCause)
        case setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose)
        case setCursorRectangle(LogicalRect)
        case showInputPanel
        case hideInputPanel
        case commit
        case destroy
    }

    let seatID: SeatID
    var protocolVersion: UInt32 = 2
    private(set) var operations: [Operation] = []
    var onOperation: ((Operation) -> Void)?

    init(seatID bindingSeatID: SeatID) {
        seatID = bindingSeatID
    }

    func enable() {
        record(.enable)
    }

    func disable() {
        record(.disable)
    }

    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32) {
        record(
            .setSurroundingText(text, cursor: cursor, anchor: anchor)
        )
    }

    func setTextChangeCause(_ cause: TextInputChangeCause) {
        record(.setTextChangeCause(cause))
    }

    func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose
    ) {
        record(.setContentType(hints: hints, purpose: purpose))
    }

    func setCursorRectangle(_ rect: LogicalRect) {
        record(.setCursorRectangle(rect))
    }

    func commit() {
        record(.commit)
    }

    func showInputPanel() {
        record(.showInputPanel)
    }

    func hideInputPanel() {
        record(.hideInputPanel)
    }

    func destroy() {
        record(.destroy)
    }

    private func record(_ operation: Operation) {
        operations.append(operation)
        onOperation?(operation)
    }
}
