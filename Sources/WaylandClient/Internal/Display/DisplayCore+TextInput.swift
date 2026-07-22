extension DisplayCore {
    func textInputSession(for seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.prepareSession(for: seatID)
        }
    }

    func enableTextInput(seatID: SeatID, windowID: WindowID) throws {
        try withFatalFailureFinalization {
            _ = try requireOpenWindow(windowID)
            try requireSession().textInputManager.enable(
                seatID: seatID,
                windowID: windowID
            )
        }
    }

    func disableTextInput(seatID: SeatID) throws -> TextInputCommitSerial? {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.disable(seatID: seatID)
        }
    }

    func setTextInputSurroundingText(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.setSurroundingText(
                surroundingText,
                seatID: seatID
            )
        }
    }

    func setTextInputChangeCause(_ cause: TextInputChangeCause, seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.setTextChangeCause(
                cause,
                seatID: seatID
            )
        }
    }

    func setTextInputContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.setContentType(
                hints: hints,
                purpose: purpose,
                seatID: seatID
            )
        }
    }

    func setTextInputCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.setCursorRectangle(
                rect,
                seatID: seatID
            )
        }
    }

    func commitTextInput(seatID: SeatID) throws -> TextInputCommitSerial {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.commit(seatID: seatID)
        }
    }

    func showTextInputPanel(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.showInputPanel(seatID: seatID)
        }
    }

    func hideTextInputPanel(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().textInputManager.hideInputPanel(seatID: seatID)
        }
    }

    func publishTextInputEvents(_ events: [TextInputEvent]) {
        for event in events {
            eventHub.publishTextInput(event)
        }
    }
}
