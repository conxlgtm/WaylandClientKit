import WaylandRaw

package protocol TextInputBinding: AnyObject {
    var protocolVersion: UInt32 { get }

    func enable()
    func disable()
    func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32)
    func setTextChangeCause(_ cause: TextInputChangeCause)
    func setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose)
    func setCursorRectangle(_ rect: LogicalRect)
    func commit()
    func showInputPanel()
    func hideInputPanel()
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
    private var lifecyclesBySeatID: [SeatID: TextInputSessionLifecycle] = [:]
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

    package func enable(seatID: SeatID, windowID: WindowID) throws {
        backend.preconditionIsOwnerThread()
        try binding(for: seatID).enable()
        lifecyclesBySeatID[seatID] = .enabled(windowID: windowID)
    }

    package func disable(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        guard let binding = bindingsBySeatID[seatID] else {
            return
        }

        switch lifecycle(for: seatID) {
        case .enabled, .focused:
            binding.disable()
            lifecyclesBySeatID[seatID] = .disabled
        case .inactive, .disabled:
            return
        }
    }

    package func setSurroundingText(
        _ surroundingText: TextInputSurroundingText,
        seatID: SeatID
    ) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setSurroundingText)
        let request = try TextInputSurroundingTextRequest(surroundingText)
        try existingBinding(for: seatID).setSurroundingText(
            request.text,
            cursor: request.cursorByteOffset,
            anchor: request.anchorByteOffset
        )
    }

    package func setTextChangeCause(_ cause: TextInputChangeCause, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setTextChangeCause)
        try existingBinding(for: seatID).setTextChangeCause(cause)
    }

    package func setContentType(
        hints: TextInputContentHints,
        purpose: TextInputContentPurpose,
        seatID: SeatID
    ) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setContentType)
        try existingBinding(for: seatID).setContentType(hints: hints, purpose: purpose)
    }

    package func setCursorRectangle(_ rect: LogicalRect, seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .setCursorRectangle)
        try existingBinding(for: seatID).setCursorRectangle(rect)
    }

    package func commit(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .commit)
        try existingBinding(for: seatID).commit()
    }

    package func showInputPanel(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .showInputPanel)
        let binding = try existingBinding(for: seatID)
        try requireProtocolVersion(
            binding.protocolVersion,
            minimum: 2,
            operation: .showInputPanel
        )
        binding.showInputPanel()
    }

    package func hideInputPanel(seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        try requireRequestMutation(seatID: seatID, operation: .hideInputPanel)
        let binding = try existingBinding(for: seatID)
        try requireProtocolVersion(
            binding.protocolVersion,
            minimum: 2,
            operation: .hideInputPanel
        )
        binding.hideInputPanel()
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
        lifecyclesBySeatID.removeAll(keepingCapacity: false)
        _ = eventQueue.drain()
    }

    package func removeSeat(_ seatID: SeatID) {
        backend.preconditionIsOwnerThread()
        guard let binding = bindingsBySeatID.removeValue(forKey: seatID) else {
            return
        }

        binding.destroy()
        statesBySeatID.removeValue(forKey: seatID)
        lifecyclesBySeatID.removeValue(forKey: seatID)
        eventQueue.append(.diagnostic(.seatRemoved(seatID)))
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
        lifecyclesBySeatID[seatID] = .inactive
        return binding
    }

    private func existingBinding(for seatID: SeatID) throws -> any TextInputBinding {
        if let binding = bindingsBySeatID[seatID] {
            return binding
        }

        throw TextInputError.unknownSeat(seatID)
    }

    private func lifecycle(for seatID: SeatID) -> TextInputSessionLifecycle {
        lifecyclesBySeatID[seatID] ?? .inactive
    }

    private func requireRequestMutation(
        seatID: SeatID,
        operation: TextInputRequestOperation
    ) throws {
        guard bindingsBySeatID[seatID] != nil else {
            throw TextInputError.unknownSeat(seatID)
        }

        let lifecycle = lifecycle(for: seatID)
        guard lifecycle.permitsRequestMutation else {
            eventQueue.append(
                .diagnostic(
                    .invalidRequest(
                        seatID: seatID,
                        operation: operation,
                        lifecycle: lifecycle
                    )
                )
            )
            throw TextInputError.inactiveSession(
                seatID: seatID,
                operation: operation
            )
        }
    }

    private func requireProtocolVersion(
        _ available: UInt32,
        minimum required: UInt32,
        operation: TextInputRequestOperation
    ) throws {
        guard available >= required else {
            throw TextInputError.unsupportedVersion(
                operation: operation,
                required: required,
                available: available
            )
        }
    }

    private func handleRawEvent(_ event: RawTextInputEvent, seatID: SeatID) {
        guard !isShutdown else { return }
        guard bindingsBySeatID[seatID] != nil else { return }

        let protocolEvent = textInputProtocolEvent(from: event)
        updateLifecycle(for: seatID, event: protocolEvent)
        var state = statesBySeatID[seatID] ?? TextInputState(seatID: seatID)
        let events = state.reduce(protocolEvent)
        statesBySeatID[seatID] = state
        eventQueue.append(contentsOf: events)
    }

    private func updateLifecycle(for seatID: SeatID, event: TextInputProtocolEvent) {
        switch event {
        case .enter(let target):
            var lifecycle = lifecycle(for: seatID)
            lifecycle.markEntered(target)
            lifecyclesBySeatID[seatID] = lifecycle
        case .leave(let target):
            var lifecycle = lifecycle(for: seatID)
            lifecycle.markLeft(target)
            lifecyclesBySeatID[seatID] = lifecycle
        case .preeditString, .commitString, .deleteSurroundingText, .done, .action,
            .language, .preeditHint:
            break
        }
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
            .language(language.textInputLanguage)
        case .preeditHint(let hint):
            .preeditHint(hint.textInputPreeditHint)
        }
    }
}
