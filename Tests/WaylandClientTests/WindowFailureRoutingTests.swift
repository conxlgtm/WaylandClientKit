import Testing

@testable import WaylandClient

@Suite
struct WindowFailureRoutingTests {
    @Test
    func windowFailureDiagnosticPublishesDisplayDiagnostic() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 9)
        let diagnostic = WindowDiagnostic(
            windowID: windowID,
            operation: .callback("frameDone"),
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
