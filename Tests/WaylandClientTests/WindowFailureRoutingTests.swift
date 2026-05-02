import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowFailureClassifierTests {
    private let windowID = WindowID(rawValue: 11)

    @Test
    func classifiesDisplayClosedCallbackAsDiagnostic() {
        let failure = WindowFailureClassifier.classify(
            windowID: windowID,
            operation: .frameDone,
            error: ClientError.displayClosed
        )

        #expect(
            failure
                == .diagnostic(
                    WindowDiagnostic(
                        windowID: windowID,
                        operation: .callback(.frameDone),
                        message: ClientError.displayClosed.description
                    )
                )
        )
    }

    @Test
    func classifiesLifecycleViolationAsFatalWindowFailure() {
        let transition = WindowLifecycleTransitionError.redrawAfterDestroyed
        let failure = WindowFailureClassifier.classify(
            windowID: windowID,
            operation: .markNeedsRedraw,
            error: ClientError.window(
                windowID,
                .invalidLifecycleTransition(transition)
            )
        )

        #expect(failure == .lifecycleViolation(windowID, transition))
    }

    @Test
    func classifiesInvalidConfigureDimensionsAsProtocolViolation() {
        let failure = WindowFailureClassifier.classify(
            windowID: windowID,
            operation: .closeRequested,
            error: ClientError.window(
                windowID,
                .invalidConfigure(.negativeSuggestedDimension(width: -1, height: 480))
            )
        )

        #expect(
            failure
                == .protocolViolation(
                    .invalidXDGConfigureDimensions(
                        windowID: windowID,
                        width: -1,
                        height: 480
                    )
                )
        )
    }

    @Test
    func classifiesUnexpectedClientErrorAsInternalInvariant() {
        let error = ClientError.unknownWindow(WindowID(rawValue: 99))
        let failure = WindowFailureClassifier.classify(
            windowID: windowID,
            operation: .bufferReleased,
            error: error
        )

        #expect(
            failure
                == .internalInvariant(
                    .unexpectedWindowCallbackError(
                        windowID,
                        operation: .bufferReleased,
                        detail: error.description
                    )
                )
        )
    }

    @Test
    func classifiesRuntimeProtocolErrorAsProtocolViolation() {
        let failure = WindowFailureClassifier.classify(
            windowID: windowID,
            operation: .frameDone,
            error: RuntimeError.protocolError(
                interfaceName: "xdg_surface",
                objectID: 42,
                code: 7
            )
        )

        #expect(
            failure
                == .protocolViolation(
                    .display(interface: "xdg_surface", objectID: 42, code: 7)
                )
        )
    }
}

@Suite
struct WindowFailureRoutingTests {
    @Test
    func windowFailureDiagnosticPublishesDisplayDiagnostic() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 9)
        let diagnostic = WindowDiagnostic(
            windowID: windowID,
            operation: .callback(.frameDone),
            message: "frame callback arrived after close"
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        core.reportWindowFailure(.diagnostic(diagnostic))

        let expected = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .window(diagnostic)
        )
        await expectNext(.diagnostic(expected), from: &displayIterator)
        await expectDiagnosticNext(expected, from: &diagnosticsIterator)
    }

    @Test
    func fatalWindowFailureTerminatesDisplayAndInputStreams() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 7)
        let invariant = InternalInvariantViolation.effectInterpreterInvariant(
            windowID,
            "ackConfigure without xdg_surface"
        )
        let expectedError = WaylandDisplayError.internalInvariantViolation(invariant)
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        core.reportWindowFailure(.internalInvariant(invariant))

        await expectFailure(expectedError, from: &displayIterator)
        await expectFailure(expectedError, from: &inputIterator)
    }

    @Test
    func presentationFailurePublishesWindowDiagnostic() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 8)
        let error = PresentationError.drawFailed("paint failed")
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        core.reportWindowFailure(.presentationFailure(windowID, error))

        let expected = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .window(
                WindowDiagnostic(
                    windowID: windowID,
                    operation: .presentation(.presentationFailed),
                    message: error.description
                )
            )
        )
        await expectNext(.diagnostic(expected), from: &displayIterator)
        await expectDiagnosticNext(expected, from: &diagnosticsIterator)
    }

    @Test
    func lifecycleViolationTerminatesDisplayAndInputStreams() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 12)
        let transition = WindowLifecycleTransitionError.presentWhileClosing
        let expectedError = WaylandDisplayError.internalInvariantViolation(
            .invalidWindowTransition(windowID, transition: transition)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        core.reportWindowFailure(.lifecycleViolation(windowID, transition))

        await expectFailure(expectedError, from: &displayIterator)
        await expectFailure(expectedError, from: &inputIterator)
    }

    @Test
    func protocolViolationTerminatesDisplayAndInputStreams() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 13)
        let protocolError = WaylandProtocolError.invalidConfigureSerial(
            windowID: windowID,
            serial: 0
        )
        let expectedError = WaylandDisplayError.protocolError(protocolError)
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        core.reportWindowFailure(.protocolViolation(protocolError))

        await expectFailure(expectedError, from: &displayIterator)
        await expectFailure(expectedError, from: &inputIterator)
    }
}

private func expectNext(
    _ expectedEvent: DisplayEvent,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected display event, got \(error)")
    }
}

private func expectDiagnosticNext(
    _ expectedDiagnostic: DisplayDiagnostic,
    from iterator: inout DisplayDiagnosticsIterator
) async {
    do {
        let diagnostic = try await iterator.next()
        #expect(diagnostic == expectedDiagnostic)
    } catch {
        Issue.record("Expected diagnostic event, got \(error)")
    }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected display stream failure")
    } catch {
        #expect(error == expectedError)
    }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout InputEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected input stream failure")
    } catch {
        #expect(error == expectedError)
    }
}
