public struct TextInputSession: Sendable, Hashable {
    public let seatID: SeatID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<SeatID>

    package init(seatID sessionSeatID: SeatID, display owningDisplay: WaylandDisplay) {
        seatID = sessionSeatID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: sessionSeatID, display: owningDisplay)
    }

    public func enable(for window: Window) async throws {
        guard window.isOwned(by: display) else {
            throw TextInputError.foreignWindow(window.id)
        }

        try await display.enableTextInput(seatID: seatID, windowID: window.id)
    }

    @discardableResult
    public func disable() async throws -> TextInputCommitSerial? {
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

    @discardableResult
    public func commit() async throws -> TextInputCommitSerial {
        try await display.commitTextInput(seatID: seatID)
    }

    public func showInputPanel() async throws {
        try await display.showTextInputPanel(seatID: seatID)
    }

    public func hideInputPanel() async throws {
        try await display.hideTextInputPanel(seatID: seatID)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
