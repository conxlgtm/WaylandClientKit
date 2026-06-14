extension DisplayCore {
    func textInputSession(for seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().prepareTextInputSessionOnOwnerThread(for: seatID)
        }
    }

    func enableTextInput(seatID: SeatID, windowID: WindowID) throws {
        try withFatalFailureFinalization {
            _ = try requireOpenWindow(windowID)
            try requireSession().enableTextInputOnOwnerThread(
                seatID: seatID,
                windowID: windowID
            )
        }
    }

    func disableTextInput(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().disableTextInputOnOwnerThread(seatID: seatID)
        }
    }

    func setTextInputSurroundingText(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        try withFatalFailureFinalization {
            try requireSession().setTextInputSurroundingTextOnOwnerThread(
                surroundingText,
                seatID: seatID
            )
        }
    }

    func setTextInputChangeCause(_ cause: TextInputChangeCause, seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().setTextInputChangeCauseOnOwnerThread(
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
            try requireSession().setTextInputContentTypeOnOwnerThread(
                hints: hints,
                purpose: purpose,
                seatID: seatID
            )
        }
    }

    func setTextInputCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().setTextInputCursorRectangleOnOwnerThread(
                rect,
                seatID: seatID
            )
        }
    }

    func commitTextInput(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().commitTextInputOnOwnerThread(seatID: seatID)
        }
    }

    func showTextInputPanel(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().showTextInputPanelOnOwnerThread(seatID: seatID)
        }
    }

    func hideTextInputPanel(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().hideTextInputPanelOnOwnerThread(seatID: seatID)
        }
    }

    func publishTextInputEvents(_ events: [TextInputEvent]) {
        for event in events {
            eventHub.publishTextInput(event)
        }
    }
}
