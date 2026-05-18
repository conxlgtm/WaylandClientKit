import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubStreamTerminationTests {
    @Test
    func fatalInternalInvariantTerminatesEveryStream() async {
        let hub = DisplayEventHub()
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()
        var dataTransferIterator = hub.dataTransferEvents().makeAsyncIterator()
        var textInputIterator = hub.textInputEvents().makeAsyncIterator()
        let presentationEvents = hub.windowPresentationEvents(windowID: WindowID(rawValue: 7))
        var presentationIterator = presentationEvents.makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("listener state lost")
        )

        hub.finish(throwing: error)

        await expectFailure(error, from: &displayIterator)
        await expectFailure(error, from: &inputIterator)
        await expectFailure(error, from: &dataTransferIterator)
        await expectFailure(error, from: &textInputIterator)
        await expectFailure(error, from: &presentationIterator)
        await expectFailure(error, from: &diagnosticsIterator)
    }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected display stream failure")
    } catch { #expect(error == expectedError) }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout InputEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected input stream failure")
    } catch { #expect(error == expectedError) }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DataTransferEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected data transfer stream failure")
    } catch { #expect(error == expectedError) }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout TextInputEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected text-input stream failure")
    } catch { #expect(error == expectedError) }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout WindowPresentationEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected presentation stream failure")
    } catch { #expect(error == expectedError) }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DisplayDiagnosticsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected diagnostics stream failure")
    } catch { #expect(error == expectedError) }
}
