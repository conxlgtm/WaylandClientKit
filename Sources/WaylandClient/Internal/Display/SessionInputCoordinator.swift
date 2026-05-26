import WaylandCursor
import WaylandKeyboard
import WaylandRaw

final class SessionInputCoordinator {
    private let inputRouter: InputRouter
    private let keyboardInterpreter: KeyboardInterpreter
    private let cursorManager: CursorManager
    private let maximumPendingInputEventCount: Int
    private var pendingInputState = PendingInputState.accepting([])

    init(
        inputRouter sessionInputRouter: InputRouter,
        keyboardInterpreter sessionKeyboardInterpreter: KeyboardInterpreter,
        cursorManager sessionCursorManager: CursorManager,
        maximumPendingInputEventCount sessionMaximumPendingInputEventCount: Int
    ) {
        inputRouter = sessionInputRouter
        keyboardInterpreter = sessionKeyboardInterpreter
        cursorManager = sessionCursorManager
        maximumPendingInputEventCount = sessionMaximumPendingInputEventCount
    }

    var pointerCursor: PointerCursor {
        cursorManager.pointerCursor
    }

    @discardableResult
    func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try cursorManager.setPointerCursor(cursor)
    }

    func target(for rawObjectID: RawObjectID?) -> InputEventTarget {
        inputRouter.target(for: rawObjectID)
    }

    func registerWindow(windowID: WindowID, surfaceID: RawObjectID) {
        inputRouter.register(windowID: windowID, surfaceID: surfaceID)
        cursorManager.register(surfaceID: surfaceID)
    }

    func registerPopup(
        popupID: PopupID,
        parentSurfaceID: RawObjectID,
        surfaceID: RawObjectID
    ) throws {
        try inputRouter.registerPopup(
            popupID: popupID,
            parentSurfaceID: parentSurfaceID,
            surfaceID: surfaceID
        )
        cursorManager.register(surfaceID: surfaceID)
    }

    func unregisterSurface(_ surfaceID: RawObjectID) {
        inputRouter.unregister(surfaceID: surfaceID)
        cursorManager.unregister(surfaceID: surfaceID)
    }

    func updateCursorOutputScales(
        surfaceID: RawObjectID,
        focusedOutputs: [CursorOutputScale],
        availableOutputs: [CursorOutputScale]
    ) throws {
        try cursorManager.updateOutputScales(
            for: surfaceID,
            focusedOutputs: focusedOutputs,
            availableOutputs: availableOutputs
        )
    }

    func updateAvailableCursorOutputScales(
        availableOutputs: [CursorOutputScale]
    ) throws {
        try cursorManager.updateAvailableOutputScales(availableOutputs)
    }

    func shutdown() {
        cursorManager.shutdown()
    }

    func drainInputEvents() -> [InputEvent] {
        pendingInputState.drain()
    }

    func processPendingSessionInputEvents(
        from rawEvents: [RawInputEvent],
        onSeatRemoved: (SeatID) -> Void,
        onPointerCapabilityLost: (SeatID) -> Void
    ) {
        guard !pendingInputState.hasFailed else { return }

        let routedEvents = routeSessionInputEvents(
            from: rawEvents,
            inputRouter: inputRouter,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )

        for inputEvent in routedEvents {
            switch inputEvent.kind {
            case .seat(.removed):
                onSeatRemoved(inputEvent.seatID)
            case .seat(.changed(let snapshot)) where !snapshot.activeCapabilities.hasPointer:
                onPointerCapabilityLost(inputEvent.seatID)
            default:
                continue
            }
        }

        appendPendingInputEvents(routedEvents)
    }

    private func appendPendingInputEvents(_ inputEvents: [InputEvent]) {
        guard !inputEvents.isEmpty else { return }
        pendingInputState.append(
            inputEvents,
            capacity: maximumPendingInputEventCount,
            makeOverflowEvent: makePendingInputOverflowDiagnostic
        )
    }

    private func makePendingInputOverflowDiagnostic(from event: InputEvent) -> InputEvent {
        InputEvent(
            sequence: event.sequence,
            seatID: event.seatID,
            target: .display,
            kind: .diagnostic(
                InputDiagnostic(
                    .inputPipelineOverflow(
                        InputPipelineOverflow(
                            stage: .sessionPendingInput,
                            capacity: InputPipelineCapacity(
                                unchecked: maximumPendingInputEventCount
                            )
                        )
                    )
                )
            )
        )
    }
}

enum PendingInputState {
    case accepting([InputEvent])
    case failed(bufferedPrefix: [InputEvent], overflow: PendingInputOverflowEvent)
    case drainedAfterFailure

    var hasFailed: Bool {
        switch self {
        case .accepting:
            false
        case .failed, .drainedAfterFailure:
            true
        }
    }

    mutating func append(
        _ inputEvents: [InputEvent],
        capacity: Int,
        makeOverflowEvent: (InputEvent) -> InputEvent
    ) {
        guard case .accepting(var pendingEvents) = self else { return }

        for inputEvent in inputEvents {
            if let overflow = PendingInputOverflowEvent(inputEvent) {
                self = .failed(bufferedPrefix: pendingEvents, overflow: overflow)
                return
            }

            guard pendingEvents.count < capacity else {
                self = .failed(
                    bufferedPrefix: pendingEvents,
                    overflow: PendingInputOverflowEvent(
                        from: inputEvent,
                        makeOverflowEvent: makeOverflowEvent
                    )
                )
                return
            }

            pendingEvents.append(inputEvent)
        }

        self = .accepting(pendingEvents)
    }

    mutating func drain() -> [InputEvent] {
        switch self {
        case .accepting(let inputEvents):
            self = .accepting([])
            return inputEvents
        case .failed(let bufferedPrefix, let overflow):
            self = .drainedAfterFailure
            return bufferedPrefix + [overflow.inputEvent]
        case .drainedAfterFailure:
            return []
        }
    }
}

struct PendingInputOverflowEvent {
    let inputEvent: InputEvent

    init?(_ event: InputEvent) {
        guard Self.isInputPipelineOverflowDiagnostic(event) else { return nil }
        inputEvent = event
    }

    init(
        from rejectedEvent: InputEvent,
        makeOverflowEvent: (InputEvent) -> InputEvent
    ) {
        let overflow = makeOverflowEvent(rejectedEvent)
        precondition(
            Self.isInputPipelineOverflowDiagnostic(overflow),
            "Pending input overflow event must be an input-pipeline overflow diagnostic"
        )
        inputEvent = overflow
    }

    private static func isInputPipelineOverflowDiagnostic(_ event: InputEvent) -> Bool {
        guard case .diagnostic(let diagnostic) = event.kind else { return false }
        if case .inputPipelineOverflow = diagnostic.operation {
            return true
        }

        return false
    }
}

func routeSessionInputEvents(
    from rawEvents: [RawInputEvent],
    inputRouter: InputRouter,
    keyboardInterpreter: KeyboardInterpreter,
    rawInputObserver: RawInputEventObserving? = nil
) -> [InputEvent] {
    var inputEvents: [InputEvent] = []
    for rawEvent in rawEvents {
        if let acceptedEvent = inputRouter.acceptRawInputEvent(rawEvent) {
            inputEvents.append(contentsOf: rawInputObserver?.observe(acceptedEvent.raw) ?? [])
            inputEvents.append(contentsOf: inputRouter.route(acceptedEvent))

            for interpretedEvent in keyboardInterpreter.consume(acceptedEvent.raw) {
                inputEvents.append(contentsOf: inputRouter.route(interpretedEvent))
            }
        }
    }

    return inputEvents
}
