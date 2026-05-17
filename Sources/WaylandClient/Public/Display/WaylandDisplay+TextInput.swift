extension WaylandDisplay {
    public nonisolated var textInputEvents: TextInputEvents {
        runtime.textInputEvents
    }

    public func textInputSession(for seatID: SeatID) throws -> TextInputSession {
        try requireCore().textInputSession(for: seatID)
        return TextInputSession(seatID: seatID, display: self)
    }

    package func enableTextInput(seatID: SeatID, windowID: WindowID) throws {
        try requireCore().enableTextInput(seatID: seatID, windowID: windowID)
    }

    package func disableTextInput(seatID: SeatID) throws {
        try requireCore().disableTextInput(seatID: seatID)
    }

    package func setTextInputSurroundingText(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        try requireCore().setTextInputSurroundingText(
            surroundingText,
            seatID: seatID
        )
    }

    package func setTextInputChangeCause(_ cause: TextInputChangeCause, seatID: SeatID)
        throws
    {
        try requireCore().setTextInputChangeCause(cause, seatID: seatID)
    }

    package func setTextInputContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        try requireCore().setTextInputContentType(
            hints: hints,
            purpose: purpose,
            seatID: seatID
        )
    }

    package func setTextInputCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        try requireCore().setTextInputCursorRectangle(rect, seatID: seatID)
    }

    package func commitTextInput(seatID: SeatID) throws {
        try requireCore().commitTextInput(seatID: seatID)
    }
}

extension WaylandDisplayRuntime {
    var textInputEvents: TextInputEvents {
        eventHub.textInputEvents()
    }
}
