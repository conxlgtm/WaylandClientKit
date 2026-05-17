import WaylandRaw

package enum TextInputProtocolEvent: Equatable, Sendable {
    case enter(InputEventTarget)
    case leave(InputEventTarget)
    case preeditString(RawTextInputPreedit)
    case commitString(String)
    case deleteSurroundingText(beforeLength: UInt32, afterLength: UInt32)
    case done(serial: UInt32)
    case action(action: TextInputAction, serial: UInt32)
    case language(TextInputLanguage)
    case preeditHint(TextInputPreeditHint)
}

package struct TextInputTransaction: Equatable, Sendable {
    package var preedit: TextInputPreeditEvent?
    package var deleteSurroundingText: TextInputDeleteSurroundingTextEvent?
    package var commit: TextInputCommitEvent?
    package var action: TextInputActionEvent?
    package var done: TextInputDoneEvent

    package var events: [TextInputEvent] {
        var transactionEvents: [TextInputEvent] = []
        if let preedit {
            transactionEvents.append(.preedit(preedit))
        }
        if let deleteSurroundingText {
            transactionEvents.append(.deleteSurroundingText(deleteSurroundingText))
        }
        if let commit {
            transactionEvents.append(.committed(commit))
        }
        if let action {
            transactionEvents.append(.action(action))
        }
        transactionEvents.append(.done(done))
        return transactionEvents
    }
}

private struct PendingTextInputTransaction: Equatable, Sendable {
    var preedit: RawTextInputPreedit?
    var commitString: String?
    var deleteSurroundingText: TextInputDeleteSurroundingTextEvent?
    var action: TextInputActionEvent?
    var preeditHints: [TextInputPreeditHint] = []

    mutating func reset() {
        preedit = nil
        commitString = nil
        deleteSurroundingText = nil
        action = nil
        preeditHints.removeAll(keepingCapacity: true)
    }
}

package struct TextInputState: Equatable, Sendable {
    package let seatID: SeatID
    private var pending = PendingTextInputTransaction()

    package init(seatID stateSeatID: SeatID) {
        seatID = stateSeatID
    }

    package mutating func reduce(_ event: TextInputProtocolEvent) -> [TextInputEvent] {
        switch event {
        case .enter(let target):
            pending.reset()
            return [.entered(TextInputFocusEvent(seatID: seatID, target: target))]
        case .leave(let target):
            pending.reset()
            return [.left(TextInputFocusEvent(seatID: seatID, target: target))]
        case .preeditString(let preedit):
            pending.preedit = preedit
            return []
        case .commitString(let text):
            pending.commitString = text
            return []
        case .deleteSurroundingText(let beforeLength, let afterLength):
            pending.deleteSurroundingText = TextInputDeleteSurroundingTextEvent(
                seatID: seatID,
                beforeLength: beforeLength,
                afterLength: afterLength
            )
            return []
        case .action(let action, let serial):
            pending.action = TextInputActionEvent(
                seatID: seatID,
                action: action,
                serial: serial
            )
            return []
        case .language(let language):
            return [.language(TextInputLanguageEvent(seatID: seatID, language: language))]
        case .preeditHint(let hint):
            pending.preeditHints.append(hint)
            return []
        case .done(let serial):
            let events = committedTransaction(serial: serial).events
            pending.reset()
            return events
        }
    }

    package func committedTransaction(serial: UInt32) -> TextInputTransaction {
        let preeditEvent: TextInputPreeditEvent?
        if let preedit = pending.preedit {
            preeditEvent = TextInputPreeditEvent(
                seatID: seatID,
                text: preedit.text ?? "",
                cursorBegin: preedit.cursorBegin,
                cursorEnd: preedit.cursorEnd,
                hints: pending.preeditHints
            )
        } else {
            preeditEvent = nil
        }

        let commitEvent: TextInputCommitEvent?
        if let commitString = pending.commitString {
            commitEvent = TextInputCommitEvent(seatID: seatID, text: commitString)
        } else {
            commitEvent = nil
        }

        return TextInputTransaction(
            preedit: preeditEvent,
            deleteSurroundingText: pending.deleteSurroundingText,
            commit: commitEvent,
            action: pending.action,
            done: TextInputDoneEvent(seatID: seatID, serial: serial)
        )
    }
}

package enum TextInputSessionLifecycle: Equatable, Sendable {
    case inactive
    case enabled(windowID: WindowID)
    case focused(target: InputEventTarget)
    case disabled

    package var permitsRequestMutation: Bool {
        switch self {
        case .enabled, .focused:
            true
        case .inactive, .disabled:
            false
        }
    }

    package mutating func markEntered(_ target: InputEventTarget) {
        switch self {
        case .enabled, .focused:
            self = .focused(target: target)
        case .inactive, .disabled:
            break
        }
    }

    package mutating func markLeft(_ target: InputEventTarget) {
        guard case .focused = self else { return }

        switch target {
        case .surface(let surfaceTarget):
            self = .enabled(windowID: surfaceTarget.windowID)
        case .display, .unmanagedSurface, .focusless:
            self = .disabled
        }
    }
}

extension TextInputDiagnostic {
    package static func invalidRequest(
        seatID: SeatID,
        operation: TextInputRequestOperation,
        lifecycle: TextInputSessionLifecycle
    ) -> TextInputDiagnostic {
        TextInputDiagnostic(
            seatID: seatID,
            operation: .invalidRequest(operation),
            message: "ignored text-input \(operation.description) request in \(lifecycle)"
        )
    }

    package static func seatRemoved(_ seatID: SeatID) -> TextInputDiagnostic {
        TextInputDiagnostic(
            seatID: seatID,
            operation: .seatRemoved,
            message: "text-input seat \(seatID) was removed"
        )
    }
}
