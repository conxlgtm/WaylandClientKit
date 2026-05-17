extension DisplaySession {
    package func prepareTextInputSessionOnOwnerThread(for seatID: SeatID) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.prepareSession(for: seatID)
    }

    package func enableTextInputOnOwnerThread(seatID: SeatID) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.enable(seatID: seatID)
    }

    package func disableTextInputOnOwnerThread(seatID: SeatID) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.disable(seatID: seatID)
    }

    package func setTextInputSurroundingTextOnOwnerThread(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.setSurroundingText(
            surroundingText,
            seatID: seatID
        )
    }

    package func setTextInputChangeCauseOnOwnerThread(
        _ cause: TextInputChangeCause,
        seatID: SeatID
    ) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.setTextChangeCause(cause, seatID: seatID)
    }

    package func setTextInputContentTypeOnOwnerThread(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.setContentType(
            hints: hints,
            purpose: purpose,
            seatID: seatID
        )
    }

    package func setTextInputCursorRectangleOnOwnerThread(
        _ rect: LogicalRect,
        seatID: SeatID
    ) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.setCursorRectangle(rect, seatID: seatID)
    }

    package func commitTextInputOnOwnerThread(seatID: SeatID) throws {
        connection.preconditionIsOwnerThread()
        try textInputManager.commit(seatID: seatID)
    }

    package func drainTextInputEventsOnOwnerThread() -> [TextInputEvent] {
        connection.preconditionIsOwnerThread()
        return textInputManager.drainEvents()
    }
}
