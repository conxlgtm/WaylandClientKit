extension DisplayCore {
    func textInputSession(for seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().prepareTextInputSessionOnOwnerThread(for: seatID)
        }
    }

    func enableTextInput(seatID: SeatID, windowID: WindowID) throws {
        try withFatalFailureFinalization {
            _ = try requireOpenWindow(windowID)
            try requireSession().enableTextInputOnOwnerThread(seatID: seatID)
        }
    }

    func disableTextInput(seatID: SeatID) throws {
        try withFatalFailureFinalization {
            try requireSession().disableTextInputOnOwnerThread(seatID: seatID)
        }
    }

    func setTextInputSurroundingText(
        _ text: String,
        seatID: SeatID,
        cursor: String.Index,
        anchor: String.Index
    ) throws {
        try withFatalFailureFinalization {
            try requireSession().setTextInputSurroundingTextOnOwnerThread(
                text,
                seatID: seatID,
                cursor: cursor,
                anchor: anchor
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

    func publishTextInputEvents(_ events: [TextInputEvent]) {
        for event in events {
            eventHub.publishTextInput(event)
        }
    }
}
