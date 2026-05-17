import WaylandRaw

package protocol TextInputBinding: AnyObject {
    var seatID: SeatID { get }

    func enable()
    func disable()
    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32)
    func setTextChangeCause(_ cause: TextInputChangeCause)
    func setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose)
    func setCursorRectangle(_ rect: LogicalRect)
    func commit()
    func destroy()
}

package protocol TextInputManagerBackend: AnyObject {
    func preconditionIsOwnerThread()

    func bindTextInput(
        for seatID: SeatID,
        onEvent: @escaping (RawTextInputEvent) -> Void
    ) throws -> any TextInputBinding
}

package final class TextInputManager {
    package let backend: any TextInputManagerBackend
    private let targetResolver: (RawObjectID?) -> InputEventTarget
    private var bindingsBySeatID: [SeatID: any TextInputBinding] = [:]
    private var statesBySeatID: [SeatID: TextInputState] = [:]
    private var eventQueue = TextInputEventQueue()
    private var isShutdown = false

    package init(
        connection rawConnection: RawDisplayConnection,
        targetResolver inputTargetResolver: @escaping (RawObjectID?) -> InputEventTarget
    ) {
        backend = LiveTextInputManagerBackend(connection: rawConnection)
        targetResolver = inputTargetResolver
    }

    package init(
        backend managerBackend: any TextInputManagerBackend,
        targetResolver inputTargetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            { _ in .unmanagedSurface }
    ) {
        managerBackend.preconditionIsOwnerThread()
        backend = managerBackend
        targetResolver = inputTargetResolver
    }

    package func prepareSession(for seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        _ = try binding(for: seatID)
    }

    package func enable(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).enable()
    }

    package func disable(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).disable()
    }

    package func setSurroundingText(
        _ text: String,
        seatID: SeatID,
        cursor: String.Index,
        anchor: String.Index
    ) throws {
        backend.preconditionIsOwnerThread()
        let request = try TextInputSurroundingTextRequest(
            text: text,
            cursor: cursor,
            anchor: anchor
        )
        try binding(for: seatID).setSurroundingText(
            request.text,
            cursor: request.cursorByteOffset,
            anchor: request.anchorByteOffset
        )
    }

    package func setTextChangeCause(_ cause: TextInputChangeCause, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).setTextChangeCause(cause)
    }

    package func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).setContentType(hints: hints, purpose: purpose)
    }

    package func setCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).setCursorRectangle(rect)
    }

    package func commit(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).commit()
    }

    package func drainEvents() -> [TextInputEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    package func shutdown() {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else { return }

        isShutdown = true
        for seatID in bindingsBySeatID.keys.sortedByRawValue() {
            bindingsBySeatID.removeValue(forKey: seatID)?.destroy()
        }
        statesBySeatID.removeAll(keepingCapacity: false)
        _ = eventQueue.drain()
    }

    private func binding(for seatID: SeatID) throws -> any TextInputBinding {
        guard !isShutdown else {
            throw TextInputError.unavailable
        }

        if let binding = bindingsBySeatID[seatID] {
            return binding
        }

        let binding = try backend.bindTextInput(for: seatID) { [weak self] event in
            self?.handleRawEvent(event, seatID: seatID)
        }
        bindingsBySeatID[seatID] = binding
        statesBySeatID[seatID] = TextInputState(seatID: seatID)
        return binding
    }

    private func handleRawEvent(_ event: RawTextInputEvent, seatID: SeatID) {
        guard !isShutdown else { return }

        let protocolEvent = textInputProtocolEvent(from: event)
        var state = statesBySeatID[seatID] ?? TextInputState(seatID: seatID)
        let events = state.reduce(protocolEvent)
        statesBySeatID[seatID] = state
        eventQueue.append(contentsOf: events)
    }

    private func textInputProtocolEvent(
        from rawEvent: RawTextInputEvent
    ) -> TextInputProtocolEvent {
        switch rawEvent {
        case .enter(let surfaceID):
            .enter(targetResolver(surfaceID))
        case .leave(let surfaceID):
            .leave(targetResolver(surfaceID))
        case .preeditString(let preedit):
            .preeditString(preedit)
        case .commitString(let text):
            .commitString(text ?? "")
        case .deleteSurroundingText(let beforeLength, let afterLength):
            .deleteSurroundingText(beforeLength: beforeLength, afterLength: afterLength)
        case .done(let serial):
            .done(serial: serial)
        case .action(let action):
            .action(action: action.action.textInputAction, serial: action.serial)
        case .language(let language):
            .language(language)
        case .preeditHint(let hint):
            .preeditHint(hint.textInputPreeditHint)
        }
    }
}
