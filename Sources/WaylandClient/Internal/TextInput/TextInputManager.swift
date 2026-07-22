import WaylandRaw

package protocol TextInputBinding: AnyObject {
    var protocolVersion: UInt32 { get }

    func enable()
    func disable()
    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32)
    func setTextChangeCause(_ cause: TextInputChangeCause)
    func setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose)
    func setCursorRectangle(_ rect: LogicalRect)
    func commit()
    func showInputPanel()
    func hideInputPanel()
    func destroy()
}

package protocol TextInputManagerBackend: AnyObject {
    func preconditionIsOwnerThread()

    func bindTextInput(
        for seatID: SeatID,
        onEvent: @escaping (RawTextInputEvent) -> Void
    ) throws -> any TextInputBinding
}

private struct TextInputSeatSession {
    let binding: any TextInputBinding
    var lifecycle: TextInputSessionLifecycle
    var focusedTarget: InputEventTarget?
    var pendingTransaction: PendingTextInputTransaction
    var commitSerial: TextInputCommitSerial
}

package final class TextInputManager {
    package let backend: any TextInputManagerBackend
    private let targetResolver: (RawObjectID?) -> InputEventTarget
    private let initialCommitSerial: TextInputCommitSerial
    private var sessionsBySeatID: [SeatID: TextInputSeatSession] = [:]
    private var eventQueue = TextInputEventQueue()
    private var isShutdown = false

    package init(
        connection rawConnection: RawDisplayConnection,
        targetResolver inputTargetResolver: @escaping (RawObjectID?) -> InputEventTarget
    ) {
        backend = LiveTextInputManagerBackend(connection: rawConnection)
        targetResolver = inputTargetResolver
        initialCommitSerial = TextInputCommitSerial(rawValue: 0)
    }

    package init(
        backend managerBackend: any TextInputManagerBackend,
        targetResolver inputTargetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            { _ in .unmanagedSurface },
        initialCommitSerial: TextInputCommitSerial = TextInputCommitSerial(rawValue: 0)
    ) {
        managerBackend.preconditionIsOwnerThread()
        backend = managerBackend
        targetResolver = inputTargetResolver
        self.initialCommitSerial = initialCommitSerial
    }
}

extension TextInputManager {
    package func prepareSession(for seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        _ = try binding(for: seatID)
    }

    package func enable(seatID: SeatID, windowID: WindowID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).enable()
        guard var session = sessionsBySeatID[seatID] else {
            throw TextInputError.unknownSeat(seatID)
        }
        session.pendingTransaction.reset()
        session.lifecycle =
            if session.focusedTarget == nil {
                .enabled(windowID: windowID)
            } else {
                .focused(windowID: windowID)
            }
        sessionsBySeatID[seatID] = session
    }

    package func disable(seatID: SeatID) throws -> TextInputCommitSerial? {
        backend.preconditionIsOwnerThread()
        guard let session = sessionsBySeatID[seatID] else {
            return nil
        }

        switch session.lifecycle {
        case .enabled, .focused:
            session.binding.disable()
            session.binding.commit()
            guard var currentSession = sessionsBySeatID[seatID] else {
                return nil
            }
            currentSession.commitSerial = currentSession.commitSerial.next()
            currentSession.lifecycle = .disabled
            sessionsBySeatID[seatID] = currentSession
            return currentSession.commitSerial
        case .inactive, .disabled:
            return nil
        }
    }

    package func setSurroundingText(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setSurroundingText)
        let request = try TextInputSurroundingTextRequest(surroundingText)
        try existingBinding(for: seatID).setSurroundingText(
            request.text,
            cursor: request.cursorByteOffset,
            anchor: request.anchorByteOffset
        )
    }

    package func setTextChangeCause(_ cause: TextInputChangeCause, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setTextChangeCause)
        try existingBinding(for: seatID).setTextChangeCause(cause)
    }

    package func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setContentType)
        try existingBinding(for: seatID).setContentType(hints: hints, purpose: purpose)
    }

    package func setCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setCursorRectangle)
        try existingBinding(for: seatID).setCursorRectangle(rect)
    }

    package func commit(seatID: SeatID) throws -> TextInputCommitSerial {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .commit)
        try existingBinding(for: seatID).commit()
        guard var session = sessionsBySeatID[seatID] else {
            throw TextInputError.unknownSeat(seatID)
        }
        session.commitSerial = session.commitSerial.next()
        sessionsBySeatID[seatID] = session
        return session.commitSerial
    }

    package func showInputPanel(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .showInputPanel)
        let binding = try existingBinding(for: seatID)
        try requireProtocolVersion(
            binding.protocolVersion,
            minimum: 2,
            operation: .showInputPanel
        )
        binding.showInputPanel()
    }

    package func hideInputPanel(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .hideInputPanel)
        let binding = try existingBinding(for: seatID)
        try requireProtocolVersion(
            binding.protocolVersion,
            minimum: 2,
            operation: .hideInputPanel
        )
        binding.hideInputPanel()
    }

    package func drainEvents() -> [TextInputEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    package func shutdown() {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else { return }

        isShutdown = true
        for seatID in sessionsBySeatID.keys.sortedByRawValue() {
            sessionsBySeatID.removeValue(forKey: seatID)?.binding.destroy()
        }
        _ = eventQueue.drain()
    }

    package func removeSeat(_ seatID: SeatID) {
        backend.preconditionIsOwnerThread()
        guard let session = sessionsBySeatID.removeValue(forKey: seatID) else {
            return
        }

        session.binding.destroy()
        eventQueue.append(.diagnostic(.seatRemoved(seatID)))
    }

    private func binding(for seatID: SeatID) throws -> any TextInputBinding {
        guard !isShutdown else {
            throw TextInputError.unavailable
        }

        if let session = sessionsBySeatID[seatID] {
            return session.binding
        }

        let binding = try backend.bindTextInput(for: seatID) { [weak self] event in
            self?.handleRawEvent(event, seatID: seatID)
        }
        sessionsBySeatID[seatID] = TextInputSeatSession(
            binding: binding,
            lifecycle: .inactive,
            focusedTarget: nil,
            pendingTransaction: PendingTextInputTransaction(),
            commitSerial: initialCommitSerial
        )
        return binding
    }

    private func existingBinding(for seatID: SeatID) throws -> any TextInputBinding {
        if let session = sessionsBySeatID[seatID] {
            return session.binding
        }

        throw TextInputError.unknownSeat(seatID)
    }

    package func lifecycle(for seatID: SeatID) -> TextInputSessionLifecycle {
        sessionsBySeatID[seatID]?.lifecycle ?? .inactive
    }

    private func requireRequestMutation(
        seatID: SeatID,
        operation: TextInputRequestOperation
    ) throws {
        guard sessionsBySeatID[seatID] != nil else {
            throw TextInputError.unknownSeat(seatID)
        }

        let lifecycle = lifecycle(for: seatID)
        guard lifecycle.permitsRequestMutation else {
            eventQueue.append(
                .diagnostic(
                    .invalidRequest(
                        seatID: seatID,
                        operation: operation,
                        lifecycle: lifecycle
                    )
                )
            )
            throw TextInputError.inactiveSession(
                seatID: seatID,
                operation: operation
            )
        }
    }

    private func requireProtocolVersion(
        _ available: UInt32,
        minimum required: UInt32,
        operation: TextInputRequestOperation
    ) throws {
        guard available >= required else {
            throw TextInputError.unsupportedVersion(
                operation: operation,
                required: required,
                available: available
            )
        }
    }

    private func handleRawEvent(_ event: RawTextInputEvent, seatID: SeatID) {
        guard !isShutdown else { return }
        guard var session = sessionsBySeatID[seatID] else { return }

        let protocolEvent = textInputProtocolEvent(from: event)
        let publishedEvent = applyProtocolEvent(
            protocolEvent,
            seatID: seatID,
            to: &session
        )
        sessionsBySeatID[seatID] = session
        if let publishedEvent {
            eventQueue.append(publishedEvent)
        }
    }

    private func applyProtocolEvent(
        _ protocolEvent: TextInputProtocolEvent,
        seatID: SeatID,
        to session: inout TextInputSeatSession
    ) -> TextInputEvent? {
        switch protocolEvent {
        case .enter(let target):
            session.pendingTransaction.reset()
            session.focusedTarget = target
            session.lifecycle.markEntered()
            return .entered(TextInputFocusEvent(seatID: seatID, target: target))
        case .leave(let target):
            session.focusedTarget = nil
            session.lifecycle.markLeft()
            session.pendingTransaction.reset()
            return .left(TextInputFocusEvent(seatID: seatID, target: target))
        case .preeditString(let preedit):
            session.pendingTransaction.preedit = preedit
            return nil
        case .commitString(let text):
            session.pendingTransaction.committedText = text
            return nil
        case .deleteSurroundingText(let beforeLength, let afterLength):
            session.pendingTransaction.deletion = TextInputDeletion(
                beforeLength: beforeLength,
                afterLength: afterLength
            )
            return nil
        case .done(let rawSerial):
            let serial = TextInputCommitSerial(rawValue: rawSerial)
            let transaction = TextInputEvent.transaction(
                session.pendingTransaction.transaction(
                    seatID: seatID,
                    target: session.focusedTarget ?? .focusless,
                    serial: serial,
                    matchesLatestCommit: serial == session.commitSerial
                )
            )
            session.pendingTransaction.reset()
            return transaction
        case .action(let action):
            session.pendingTransaction.action = action
            return nil
        case .language(let language):
            return .language(
                TextInputLanguageEvent(seatID: seatID, language: language)
            )
        case .preeditHint(let hint):
            session.pendingTransaction.preeditHints.append(hint)
            return nil
        }
    }

    private func textInputProtocolEvent(
        from rawEvent: RawTextInputEvent
    ) -> TextInputProtocolEvent {
        switch rawEvent {
        case .enter(let surfaceID):
            .enter(targetResolver(surfaceID))
        case .leave(let surfaceID):
            .leave(targetResolver(surfaceID))
        case .preeditString(let preedit):
            .preeditString(preedit)
        case .commitString(let text):
            .commitString(text ?? "")
        case .deleteSurroundingText(let beforeLength, let afterLength):
            .deleteSurroundingText(beforeLength: beforeLength, afterLength: afterLength)
        case .done(let serial):
            .done(serial: serial)
        case .action(let action):
            .action(
                TextInputActionEvent(
                    action: action.action.textInputAction,
                    serial: action.serial
                )
            )
        case .language(let language):
            .language(language.textInputLanguage)
        case .preeditHint(let hint):
            .preeditHint(hint.textInputPreeditHint)
        }
    }
}

extension TextInputCommitSerial {
    package func next() -> TextInputCommitSerial {
        TextInputCommitSerial(rawValue: rawValue &+ 1)
    }
}
