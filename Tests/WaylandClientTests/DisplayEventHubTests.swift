import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubTests {
    @Test
    func displaySubscriberOverflowTerminatesOnlyThatSubscriber() async {
        let hub = DisplayEventHub(
            configuration: EventStreamConfiguration(displayEventCapacity: 1)
        )
        let firstStream = hub.displayEvents()
        let secondStream = hub.displayEvents()

        hub.publish(.windowClosed(WindowID(rawValue: 1)))
        var firstIterator = firstStream.makeAsyncIterator()
        var secondIterator = secondStream.makeAsyncIterator()
        await expectNext(.windowClosed(WindowID(rawValue: 1)), from: &secondIterator)

        hub.publish(.windowClosed(WindowID(rawValue: 2)))

        await expectOverflow(from: &firstIterator, capacity: 1)
        await expectNext(.windowClosed(WindowID(rawValue: 2)), from: &secondIterator)
    }

    @Test
    func displaySubscriberOverflowUsesConfiguredCapacity() async {
        let hub = DisplayEventHub(
            configuration: EventStreamConfiguration(displayEventCapacity: 1)
        )
        let stream = hub.displayEvents()

        hub.publish(.windowClosed(WindowID(rawValue: 1)))
        hub.publish(.windowClosed(WindowID(rawValue: 2)))

        var iterator = stream.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            Issue.record("Expected configured display event overflow")
        } catch {
            #expect(
                error
                    == .eventSubscriberOverflow(
                        stream: "display event",
                        capacity: 1
                    )
            )
        }
    }

    @Test
    func inputDiagnosticsPublishAsDisplayDiagnosticsAndInputEvents() async {
        let hub = DisplayEventHub()
        let diagnostic = InputDiagnostic(
            operation: .cursor("automaticPointerEnter"),
            message: "boom"
        )
        let inputEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 2),
            windowID: nil,
            kind: .diagnostic(diagnostic)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        hub.publishInput(inputEvent)

        await expectNext(
            .diagnostic(.input(diagnostic, severity: .degraded)),
            from: &displayIterator
        )
        await expectInputNext(inputEvent, from: &inputIterator)
    }

    @Test
    func publishingInputDiagnosticUsesDiagnosticDisplayEvent() async {
        let hub = DisplayEventHub()
        let diagnostic = InputDiagnostic(operation: .queueOverflow, message: "overflow")
        let inputEvent = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            windowID: nil,
            kind: .diagnostic(diagnostic)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.input(inputEvent))

        await expectNext(
            .diagnostic(.input(diagnostic, severity: .error)),
            from: &displayIterator
        )
    }

    @Test
    func explicitFinishEndsStreamsWithoutError() async {
        let hub = DisplayEventHub()
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.finish()

        do {
            let event = try await iterator.next()
            #expect(event == nil)
        } catch {
            Issue.record("Expected normal display stream finish, got \(error)")
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

    private func expectInputNext(
        _ expectedEvent: InputEvent,
        from iterator: inout InputEventsIterator
    ) async {
        do {
            let event = try await iterator.next()
            #expect(event == expectedEvent)
        } catch {
            Issue.record("Expected input event, got \(error)")
        }
    }

    private func expectOverflow(
        from iterator: inout DisplayEventsIterator,
        capacity: Int = 256
    ) async {
        do {
            _ = try await iterator.next()
            Issue.record("Expected display event overflow to terminate the subscriber")
        } catch {
            #expect(
                error
                    == .eventSubscriberOverflow(
                        stream: "display event",
                        capacity: capacity
                    )
            )
        }
    }
}
