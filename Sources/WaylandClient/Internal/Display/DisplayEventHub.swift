import Synchronization

@safe
private final class DiagnosticIDGenerator: Sendable {
    private let state = Mutex<UInt64>(1)

    func next() -> DiagnosticID {
        state.withLock { nextID in
            defer { nextID += 1 }
            return DiagnosticID(rawValue: nextID)
        }
    }
}

@safe
final class DisplayEventHub: Sendable {
    private let displayBroker: TypedEventBroker<DisplayEvent>
    private let inputBroker: TypedEventBroker<InputEvent>
    private let dataTransferBroker: TypedEventBroker<DataTransferEvent>
    private let textInputBroker: TypedEventBroker<TextInputEvent>
    private let presentationBroker: TypedEventBroker<WindowPresentationEvent>
    private let diagnosticsBroker: TypedEventBroker<DisplayDiagnostic>
    private let diagnosticIDGenerator: DiagnosticIDGenerator

    init(
        configuration: EventStreamConfiguration = .init(),
        diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) {
        let idGenerator = DiagnosticIDGenerator()
        diagnosticIDGenerator = idGenerator
        displayBroker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: configuration.displayEventCapacity.rawValue
        )
        inputBroker = TypedEventBroker<InputEvent>(
            stream: .inputEvents,
            capacity: configuration.inputEventCapacity.rawValue
        )
        dataTransferBroker = TypedEventBroker<DataTransferEvent>(
            stream: .dataTransferEvents,
            capacity: configuration.dataTransferEventCapacity.rawValue
        )
        textInputBroker = TypedEventBroker<TextInputEvent>(
            stream: .textInputEvents,
            capacity: configuration.textInputEventCapacity.rawValue
        )
        presentationBroker = TypedEventBroker<WindowPresentationEvent>(
            stream: .presentationEvents,
            capacity: configuration.presentationEventCapacity.rawValue
        )
        diagnosticsBroker = TypedEventBroker<DisplayDiagnostic>(
            stream: .diagnostics,
            capacity: diagnosticsConfiguration.capacity.rawValue,
            overflowStrategy: .dropOldest { count in
                DisplayDiagnostic(
                    id: idGenerator.next(),
                    severity: .warning,
                    payload: .diagnosticsDropped(count: count)
                )
            }
        )
    }

    func displayEvents() -> DisplayEvents {
        DisplayEvents(displayBroker.subscribe())
    }

    func inputEvents() -> InputEvents {
        InputEvents(inputBroker.subscribe())
    }

    func dataTransferEvents() -> DataTransferEvents {
        DataTransferEvents(dataTransferBroker.subscribe())
    }

    func textInputEvents() -> TextInputEvents {
        TextInputEvents(textInputBroker.subscribe())
    }

    func windowPresentationEvents(windowID: WindowID) -> WindowPresentationEvents {
        WindowPresentationEvents(
            windowID: windowID,
            subscription: presentationBroker.subscribe()
        )
    }

    func diagnostics() -> DisplayDiagnostics {
        DisplayDiagnostics(diagnosticsBroker.subscribe())
    }

    func publish(_ event: DisplayEvent) {
        switch event {
        case .input(let inputEvent):
            publishInput(inputEvent)
        case .diagnostic(let diagnostic):
            publishDiagnostic(diagnostic)
        case .windowCloseRequested, .windowClosed, .popupDismissed, .popupClosed,
            .redrawRequested, .popupRedrawRequested, .outputChanged, .outputRemoved,
            .windowOutputsChanged:
            displayBroker.publish(event)
        }
    }

    func publishInput(_ inputEvent: InputEvent) {
        switch inputEvent.kind {
        case .diagnostic(let diagnostic):
            let displayDiagnostic = makeDisplayDiagnostic(
                payload: .input(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
            publishDiagnostic(displayDiagnostic)
            if let overflow = inputPipelineOverflow(for: diagnostic) {
                inputBroker.finish(
                    throwing: .inputPipelineOverflow(overflow)
                )
                return
            }
        case .seat, .pointer, .keyboard, .touch, .tablet:
            guard !inputBroker.isTerminal else { return }
            displayBroker.publish(.input(inputEvent))
        }

        inputBroker.publish(inputEvent)
    }

    func publishDataTransfer(_ event: DataTransferEvent) {
        dataTransferBroker.publish(event)
    }

    func publishTextInput(_ event: TextInputEvent) {
        if case .diagnostic(let diagnostic) = event {
            publishTextInputDiagnostic(diagnostic)
        }

        textInputBroker.publish(event)
    }

    func publishPresentation(_ event: WindowPresentationEvent) {
        presentationBroker.publish(event)
    }

    func publishWindowDiagnostic(_ diagnostic: WindowDiagnostic) {
        publishDiagnostic(
            makeDisplayDiagnostic(
                payload: .window(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
        )
    }

    func publishDataTransferDiagnostic(_ diagnostic: DataTransferDiagnostic) {
        publishDiagnostic(
            makeDisplayDiagnostic(
                payload: .dataTransfer(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
        )
    }

    func publishTextInputDiagnostic(_ diagnostic: TextInputDiagnostic) {
        publishDiagnostic(
            makeDisplayDiagnostic(
                payload: .textInput(diagnostic),
                severity: displaySeverity(for: diagnostic)
            )
        )
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        displayBroker.finish(throwing: error)
        inputBroker.finish(throwing: error)
        dataTransferBroker.finish(throwing: error)
        textInputBroker.finish(throwing: error)
        presentationBroker.finish(throwing: error)
        diagnosticsBroker.finish(throwing: error)
    }

    private func displaySeverity(for diagnostic: InputDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .inputPipelineOverflow:
            .error
        case .keyboardKeymap,
            .keyboardRepeat,
            .listener,
            .seatBinding,
            .cursor,
            .unknownProtocolValue:
            .degraded
        }
    }

    private func displaySeverity(for diagnostic: WindowDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .callback,
            .lifecycle,
            .decoration,
            .presentation,
            .scale,
            .unknownProtocolValue:
            .degraded
        }
    }

    private func displaySeverity(for diagnostic: DataTransferDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .sourceWriteFailed:
            .degraded
        }
    }

    private func displaySeverity(for diagnostic: TextInputDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .invalidRequest:
            .warning
        case .unavailable,
            .listener,
            .invalidEventOrder,
            .unknownProtocolValue,
            .seatRemoved:
            .degraded
        }
    }

    private func inputPipelineOverflow(for diagnostic: InputDiagnostic) -> InputPipelineOverflow? {
        switch diagnostic.operation {
        case .inputPipelineOverflow(let overflow):
            overflow
        case .keyboardKeymap,
            .keyboardRepeat,
            .listener,
            .seatBinding,
            .cursor,
            .unknownProtocolValue:
            nil
        }
    }

    private func makeDisplayDiagnostic(
        payload diagnosticPayload: DisplayDiagnosticPayload,
        severity diagnosticSeverity: DiagnosticSeverity
    ) -> DisplayDiagnostic {
        DisplayDiagnostic(
            id: diagnosticIDGenerator.next(),
            severity: diagnosticSeverity,
            payload: diagnosticPayload
        )
    }

    private func publishDiagnostic(_ diagnostic: DisplayDiagnostic) {
        displayBroker.publish(.diagnostic(diagnostic))
        diagnosticsBroker.publish(diagnostic)
    }
}
