import WaylandRaw

final class LiveTextInputManagerBackend: TextInputManagerBackend {
    private let connection: RawDisplayConnection

    init(connection rawConnection: RawDisplayConnection) {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    func bindTextInput(
        for seatID: SeatID,
        onEvent: @escaping (RawTextInputEvent) -> Void
    ) throws -> any TextInputBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.textInputManager else {
            throw TextInputError.unavailable
        }
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw TextInputError.unknownSeat(seatID)
        }

        let textInput = try manager.getTextInput(for: seat)
        let owner = RawTextInputOwner(
            onEvent: onEvent,
            invariantFailureSink: connection.invariantFailureSink
        )
        do {
            try owner.install(on: textInput)
        } catch {
            owner.cancel()
            textInput.destroy()
            throw error
        }

        return LiveTextInputBinding(textInput: textInput, owner: owner)
    }
}

private final class LiveTextInputBinding: TextInputBinding {
    private let textInput: RawTextInput
    private let owner: RawTextInputOwner
    private var isDestroyed = false

    var protocolVersion: UInt32 {
        textInput.version.value
    }

    init(
        textInput rawTextInput: RawTextInput,
        owner listenerOwner: RawTextInputOwner
    ) {
        textInput = rawTextInput
        owner = listenerOwner
    }

    func enable() {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.enable()
    }

    func disable() {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.disable()
    }

    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32) {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.setSurroundingText(text, cursor: cursor, anchor: anchor)
    }

    func setTextChangeCause(_ cause: TextInputChangeCause) {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.setTextChangeCause(cause.rawTextInputChangeCause)
    }

    func setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose) {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.setContentType(
            hint: hints.rawTextInputContentHint,
            purpose: purpose.rawTextInputContentPurpose
        )
    }

    func setCursorRectangle(_ rect: LogicalRect) {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.setCursorRectangle(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width.rawValue,
            height: rect.size.height.rawValue
        )
    }

    func commit() {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.commit()
    }

    func showInputPanel() {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.showInputPanel()
    }

    func hideInputPanel() {
        precondition(!isDestroyed, "text-input binding was already destroyed")
        textInput.hideInputPanel()
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        owner.cancel()
        textInput.destroy()
    }

    deinit {
        destroy()
    }
}
