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

private struct PendingTextInputBatch: Equatable, Sendable {
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
    private var pending = PendingTextInputBatch()

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
            let events = committedEvents(serial: serial)
            pending.reset()
            return events
        }
    }

    private func committedEvents(serial: UInt32) -> [TextInputEvent] {
        var events: [TextInputEvent] = []
        if let preedit = pending.preedit {
            events.append(
                .preedit(
                    TextInputPreeditEvent(
                        seatID: seatID,
                        text: preedit.text ?? "",
                        cursorBegin: preedit.cursorBegin,
                        cursorEnd: preedit.cursorEnd,
                        hints: pending.preeditHints
                    )
                )
            )
        }
        if let deleteSurroundingText = pending.deleteSurroundingText {
            events.append(.deleteSurroundingText(deleteSurroundingText))
        }
        if let commitString = pending.commitString {
            events.append(
                .committed(TextInputCommitEvent(seatID: seatID, text: commitString))
            )
        }
        if let action = pending.action {
            events.append(.action(action))
        }
        events.append(.done(TextInputDoneEvent(seatID: seatID, serial: serial)))
        return events
    }
}
