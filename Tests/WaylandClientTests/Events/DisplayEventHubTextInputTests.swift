import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubTextInputTests {
    @Test
    func textInputEventsAreDeliveredOnDedicatedStream() async {
        let hub = DisplayEventHub()
        let expected = TextInputEvent.transaction(
            TextInputTransaction(
                seatID: SeatID(rawValue: 2),
                target: .focusless,
                serial: TextInputCommitSerial(rawValue: 1),
                matchesLatestCommit: true,
                preedit: nil,
                deletion: nil,
                committedText: "input",
                action: nil
            )
        )
        var iterator = hub.textInputEvents().makeAsyncIterator()

        hub.publishTextInput(expected)

        do {
            let event = try await iterator.next()
            #expect(event == expected)
        } catch {
            Issue.record("Expected text-input event, got \(error)")
        }
    }

    @Test
    func textInputCapacityIsConfiguredIndependentlyFromInputCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: EventStreamConfiguration(
                inputEventCapacity: try PositiveInt(4),
                textInputEventCapacity: try PositiveInt(1)
            )
        )
        let stream = hub.textInputEvents()
        var textIterator = stream.makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        hub.publishTextInput(
            textInputTransaction(text: "a", serial: 1)
        )
        hub.publishTextInput(
            textInputTransaction(text: "b", serial: 2)
        )
        hub.publishInput(
            InputEvent(
                sequence: 1,
                seatID: SeatID(rawValue: 2),
                target: .display,
                kind: .seat(.removed)
            )
        )

        await expectTextInputOverflow(from: &textIterator, capacity: 1)
        do {
            let inputEvent = try await inputIterator.next()
            #expect(inputEvent?.kind == .seat(.removed))
        } catch {
            Issue.record("Expected input stream to remain active, got \(error)")
        }
    }

    @Test
    func overflowingTextInputSubscriberDoesNotTerminateAnotherSubscriber() async throws {
        let hub = DisplayEventHub(
            configuration: EventStreamConfiguration(
                textInputEventCapacity: try PositiveInt(1)
            )
        )
        var overflowingIterator = hub.textInputEvents().makeAsyncIterator()
        var activeIterator = hub.textInputEvents().makeAsyncIterator()
        let first = textInputTransaction(text: "a", serial: 1)
        let second = textInputTransaction(text: "b", serial: 2)

        hub.publishTextInput(first)
        await expectTextInputNext(first, from: &activeIterator)
        hub.publishTextInput(second)

        await expectTextInputOverflow(from: &overflowingIterator, capacity: 1)
        await expectTextInputNext(second, from: &activeIterator)
    }

    @Test
    func textInputDiagnosticsPublishLocallyAndToDisplayDiagnostics() async {
        let hub = DisplayEventHub()
        let diagnostic = TextInputDiagnostic(
            seatID: SeatID(rawValue: 8),
            operation: .invalidRequest(.commit),
            message: "commit before enable"
        )
        var textIterator = hub.textInputEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishTextInput(.diagnostic(diagnostic))

        await expectTextInputNext(.diagnostic(diagnostic), from: &textIterator)
        do {
            let displayDiagnostic = try await diagnosticsIterator.next()
            #expect(
                displayDiagnostic
                    == DisplayDiagnostic(
                        id: DiagnosticID(rawValue: 1),
                        severity: .warning,
                        payload: .textInput(diagnostic)
                    )
            )
        } catch {
            Issue.record("Expected promoted text-input diagnostic, got \(error)")
        }
    }
}

private func textInputTransaction(text: String, serial: UInt32) -> TextInputEvent {
    .transaction(
        TextInputTransaction(
            seatID: SeatID(rawValue: 2),
            target: .focusless,
            serial: TextInputCommitSerial(rawValue: serial),
            matchesLatestCommit: true,
            preedit: nil,
            deletion: nil,
            committedText: text,
            action: nil
        )
    )
}

private func expectTextInputNext(
    _ expectedEvent: TextInputEvent,
    from iterator: inout TextInputEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected text-input event, got \(error)")
    }
}

private func expectTextInputOverflow(
    from iterator: inout TextInputEventsIterator,
    capacity: Int
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected text-input event overflow")
    } catch {
        #expect(
            error
                == .eventSubscriberOverflow(
                    stream: .textInputEvents,
                    capacity: capacity
                )
        )
    }
}
