import WaylandRaw

package enum TextInputProtocolEvent: Equatable, Sendable {
    case enter(InputEventTarget)
    case leave(InputEventTarget)
    case preeditString(RawTextInputPreedit)
    case commitString(String)
    case deleteSurroundingText(beforeLength: UInt32, afterLength: UInt32)
    case done(serial: UInt32)
    case action(TextInputActionEvent)
    case language(TextInputLanguage)
    case preeditHint(TextInputPreeditHint)
}

package struct PendingTextInputTransaction: Equatable, Sendable {
    var preedit: RawTextInputPreedit?
    var committedText: String?
    var deletion: TextInputDeletion?
    var action: TextInputActionEvent?
    var preeditHints: [TextInputPreeditHint] = []

    mutating func reset() {
        preedit = nil
        committedText = nil
        deletion = nil
        action = nil
        preeditHints.removeAll(keepingCapacity: true)
    }

    package func transaction(
        seatID: SeatID,
        target: InputEventTarget,
        serial: TextInputCommitSerial,
        matchesLatestCommit: Bool
    ) -> TextInputTransaction {
        let transactionPreedit: TextInputPreedit?
        if let preedit {
            transactionPreedit = TextInputPreedit(
                text: preedit.text ?? "",
                cursorBegin: preedit.cursorBegin,
                cursorEnd: preedit.cursorEnd,
                hints: preeditHints
            )
        } else {
            transactionPreedit = nil
        }

        return TextInputTransaction(
            seatID: seatID,
            target: target,
            serial: serial,
            matchesLatestCommit: matchesLatestCommit,
            preedit: transactionPreedit,
            deletion: deletion,
            committedText: committedText,
            action: action
        )
    }
}

package enum TextInputSessionLifecycle: Equatable, Sendable {
    case inactive
    case enabled(windowID: WindowID)
    case focused(windowID: WindowID)
    case disabled

    package var permitsRequestMutation: Bool {
        switch self {
        case .enabled, .focused:
            true
        case .inactive, .disabled:
            false
        }
    }

    package mutating func markEntered() {
        switch self {
        case .enabled(let windowID), .focused(let windowID):
            self = .focused(windowID: windowID)
        case .inactive, .disabled:
            break
        }
    }

    package mutating func markLeft() {
        guard case .focused(let windowID) = self else { return }
        self = .enabled(windowID: windowID)
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
