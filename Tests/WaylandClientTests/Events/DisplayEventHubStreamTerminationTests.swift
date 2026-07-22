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

    @Test
    func displayCloseDrainsPublishedEventsBeforeTerminatingEveryStream() async throws {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let events = StreamTerminationEvents()
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()
        var textInputIterator = hub.textInputEvents().makeAsyncIterator()
        var dataTransferIterator = hub.dataTransferEvents().makeAsyncIterator()
        var presentationIterator = hub.windowPresentationEvents(
            windowID: events.presentation.windowID
        ).makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publish(events.output)
        hub.publishInput(events.input)
        hub.publishTextInput(events.textInput)
        hub.publishDataTransfer(events.dataTransfer)
        hub.publishPresentation(events.presentation)
        hub.publish(.diagnostic(events.diagnostic))
        core.close()

        let expectedRootEvents = [
            events.output,
            .input(events.input),
            .textInput(events.textInput),
            .dataTransfer(events.dataTransfer),
            .presentation(events.presentation),
            .diagnostic(events.diagnostic),
        ]
        for expected in expectedRootEvents {
            #expect(try await displayIterator.next() == expected)
        }
        #expect(try await displayIterator.next() == nil)
        #expect(try await inputIterator.next() == events.input)
        #expect(try await inputIterator.next() == nil)
        #expect(try await textInputIterator.next() == events.textInput)
        #expect(try await textInputIterator.next() == nil)
        #expect(try await dataTransferIterator.next() == events.dataTransfer)
        #expect(try await dataTransferIterator.next() == nil)
        #expect(try await presentationIterator.next() == events.presentation.feedback)
        #expect(try await presentationIterator.next() == nil)
        #expect(try await diagnosticsIterator.next() == events.diagnostic)
        #expect(try await diagnosticsIterator.next() == nil)
    }
}

private struct StreamTerminationEvents {
    let output = DisplayEvent.outputRemoved(OutputID(rawValue: 1))
    let input = InputEvent(
        sequence: 2,
        seatID: SeatID(rawValue: 3),
        target: .display,
        kind: .seat(.removed)
    )
    let textInput = TextInputEvent.transaction(
        TextInputTransaction(
            seatID: SeatID(rawValue: 3),
            target: .focusless,
            serial: TextInputCommitSerial(rawValue: 4),
            matchesLatestCommit: true,
            preedit: nil,
            deletion: nil,
            committedText: "text",
            action: nil
        )
    )
    let dataTransfer = DataTransferEvent.clipboardSelectionChanged(
        ClipboardSelectionEvent(
            seatID: SeatID(rawValue: 3),
            offerID: DataOfferID(rawValue: 5)
        )
    )
    let presentation = WindowPresentationEvent(
        windowID: WindowID(rawValue: 7),
        feedback: .discarded(SurfacePresentationIdentity(rawValue: 6))
    )
    let diagnostic = DisplayDiagnostic(
        id: DiagnosticID(rawValue: 8),
        severity: .warning,
        payload: .diagnosticsDropped(count: 1)
    )
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
