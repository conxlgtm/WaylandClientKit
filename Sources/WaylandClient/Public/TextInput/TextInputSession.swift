public struct TextInputSession: Sendable, Hashable {
    public let seatID: SeatID

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(seatID sessionSeatID: SeatID, display owningDisplay: WaylandDisplay) {
        seatID = sessionSeatID
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public func enable(for window: Window) async throws {
        guard window.isOwned(by: display) else {
            throw TextInputError.foreignWindow(window.id)
        }

        try await display.enableTextInput(seatID: seatID, windowID: window.id)
    }

    public func disable() async throws {
        try await display.disableTextInput(seatID: seatID)
    }

    public func setSurroundingText(_ surroundingText: TextInputSurroundingText)
        async throws
    {
        try await display.setTextInputSurroundingText(
            surroundingText,
            seatID: seatID
        )
    }

    public func setTextChangeCause(_ cause: TextInputChangeCause) async throws {
        try await display.setTextInputChangeCause(cause, seatID: seatID)
    }

    public func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose
    ) async throws {
        try await display.setTextInputContentType(
            hints: hints,
            purpose: purpose,
            seatID: seatID
        )
    }

    public func setCursorRectangle(_ rect: LogicalRect) async throws {
        try await display.setTextInputCursorRectangle(rect, seatID: seatID)
    }

    public func commit() async throws {
        try await display.commitTextInput(seatID: seatID)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.seatID == rhs.seatID && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(seatID)
    }
}
