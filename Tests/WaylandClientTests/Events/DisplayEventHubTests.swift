// swiftlint:disable file_length

import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct DisplayEventHubTests {
    @Test
    func redrawEventPublishesExactlyOnce() async {
        let hub = DisplayEventHub()
        let windowID = WindowID(rawValue: 42)
        let stream = hub.displayEvents()

        await confirmation("redraw event delivered once", expectedCount: 1) { received in
            let task = Task {
                var iterator = stream.makeAsyncIterator()
                do {
                    while let event = try await iterator.next() {
                        guard event == .redrawRequested(windowID) else {
                            continue
                        }
                        received()
                        return
                    }
                } catch {
                    Issue.record("Expected redraw event, got \(error)")
                }
            }

            hub.publish(.redrawRequested(windowID))
            await task.value
        }
    }

    @Test
    func displaySubscriberOverflowTerminatesOnlyThatSubscriber() async throws {
        let hub = DisplayEventHub(
            configuration: try EventStreamConfiguration(displayEventCapacity: 1)
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
    func displaySubscriberOverflowUsesConfiguredCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: try EventStreamConfiguration(displayEventCapacity: 1)
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
                        stream: .displayEvents,
                        capacity: 1
                    )
            )
        }
    }

    @Test
    func inputDiagnosticsPublishAsDisplayDiagnosticsAndInputEvents() async {
        let hub = DisplayEventHub()
        let diagnostic = cursorDiagnostic("boom")
        let inputEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 2),
            target: .display,
            kind: .diagnostic(diagnostic)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        hub.publishInput(inputEvent)

        let expectedDiagnostic = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .input(diagnostic)
        )
        await expectNext(.diagnostic(expectedDiagnostic), from: &displayIterator)
        await expectInputNext(inputEvent, from: &inputIterator)
    }

    @Test
    func publishingInputDiagnosticUsesDiagnosticDisplayEvent() async {
        let hub = DisplayEventHub()
        let diagnostic = pipelineOverflowDiagnostic(
            InputPipelineOverflow(
                stage: .rawInputQueue,
                capacity: InputPipelineCapacity(unchecked: 1)
            )
        )
        let inputEvent = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .diagnostic(diagnostic)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.input(inputEvent))

        let expectedDiagnostic = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .error,
            payload: .input(diagnostic)
        )
        await expectNext(.diagnostic(expectedDiagnostic), from: &displayIterator)
    }
}

@Suite
struct DisplayDiagnosticsHubTests {
    @Test
    func diagnosticsStreamReceivesDisplayDiagnostics() async {
        let hub = DisplayEventHub()
        let diagnostic = cursorDiagnostic("boom")
        let inputEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 2),
            target: .display,
            kind: .diagnostic(diagnostic)
        )
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishInput(inputEvent)

        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 1),
                severity: .degraded,
                payload: .input(diagnostic)
            ),
            from: &diagnosticsIterator
        )
    }

    @Test
    func diagnosticsStreamDropsOldestWithoutInvertingDiagnosticIDs() async throws {
        let hub = DisplayEventHub(
            diagnosticsConfiguration: try DiagnosticsConfiguration(capacity: 1)
        )
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishInput(
            diagnosticInputEvent(sequence: 1, message: "first")
        )
        hub.publishInput(
            diagnosticInputEvent(sequence: 2, message: "second")
        )

        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 2),
                severity: .degraded,
                payload: .input(
                    cursorDiagnostic("second")
                )
            ),
            from: &diagnosticsIterator
        )
        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 3),
                severity: .warning,
                payload: .diagnosticsDropped(count: 1)
            ),
            from: &diagnosticsIterator
        )
    }

    @Test
    func diagnosticsStreamAggregatesDropNoticeWithoutUnusedNoticeIDs() async throws {
        let hub = DisplayEventHub(
            diagnosticsConfiguration: try DiagnosticsConfiguration(capacity: 1)
        )
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishInput(
            diagnosticInputEvent(sequence: 1, message: "first")
        )
        hub.publishInput(
            diagnosticInputEvent(sequence: 2, message: "second")
        )
        hub.publishInput(
            diagnosticInputEvent(sequence: 3, message: "third")
        )

        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 3),
                severity: .degraded,
                payload: .input(
                    cursorDiagnostic("third")
                )
            ),
            from: &diagnosticsIterator
        )
        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 4),
                severity: .warning,
                payload: .diagnosticsDropped(count: 2)
            ),
            from: &diagnosticsIterator
        )
    }

    @Test
    func diagnosticsContinueAfterInputPipelineOverflow() async {
        let hub = DisplayEventHub()
        let overflow = InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: InputPipelineCapacity(unchecked: 1)
        )
        let overflowDiagnostic = pipelineOverflowDiagnostic(overflow)
        let overflowEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .diagnostic(overflowDiagnostic)
        )
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishInput(overflowEvent)
        hub.publishInput(
            diagnosticInputEvent(sequence: 2, message: "cursor still reports")
        )

        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 1),
                severity: .error,
                payload: .input(overflowDiagnostic)
            ),
            from: &diagnosticsIterator
        )
        await expectDiagnosticNext(
            DisplayDiagnostic(
                id: DiagnosticID(rawValue: 2),
                severity: .degraded,
                payload: .input(
                    cursorDiagnostic("cursor still reports")
                )
            ),
            from: &diagnosticsIterator
        )
    }
}

@Suite
struct DisplayEventHubFailureTests {
    @Test
    func inputPipelineOverflowTerminatesInputStreamButDisplayContinues() async {
        let hub = DisplayEventHub()
        let overflow = InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: InputPipelineCapacity(unchecked: 1)
        )
        let diagnostic = pipelineOverflowDiagnostic(overflow)
        let inputEvent = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .diagnostic(diagnostic)
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        hub.publishInput(inputEvent)
        hub.publish(.redrawRequested(WindowID(rawValue: 9)))

        await expectNext(
            .diagnostic(
                DisplayDiagnostic(
                    id: DiagnosticID(rawValue: 1),
                    severity: .error,
                    payload: .input(diagnostic)
                )
            ),
            from: &displayIterator
        )
        await expectFailure(
            .inputPipelineOverflow(overflow),
            from: &inputIterator
        )
        await expectNext(.redrawRequested(WindowID(rawValue: 9)), from: &displayIterator)
    }

    @Test
    func inputStreamDrainsPrefixThenFailsAfterPipelineOverflow() async {
        let hub = DisplayEventHub()
        let prefixEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .seat(.removed)
        )
        let overflow = InputPipelineOverflow(
            stage: .sessionPendingInput,
            capacity: InputPipelineCapacity(unchecked: 1)
        )
        let diagnostic = pipelineOverflowDiagnostic(overflow)
        let overflowEvent = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .diagnostic(diagnostic)
        )
        var inputIterator = hub.inputEvents().makeAsyncIterator()

        hub.publishInput(prefixEvent)
        hub.publishInput(overflowEvent)

        await expectInputNext(prefixEvent, from: &inputIterator)
        await expectFailure(.inputPipelineOverflow(overflow), from: &inputIterator)
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

    @Test
    func newSubscriberAfterNormalFinishImmediatelyReturnsNil() async {
        let hub = DisplayEventHub()

        hub.finish()

        var iterator = hub.displayEvents().makeAsyncIterator()
        do {
            let event = try await iterator.next()
            #expect(event == nil)
        } catch {
            Issue.record("Expected normal display stream finish, got \(error)")
        }
    }

    @Test
    func newSubscriberAfterFailedFinishImmediatelyThrows() async {
        let hub = DisplayEventHub()
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("listener state lost")
        )

        hub.finish(throwing: error)

        var iterator = hub.displayEvents().makeAsyncIterator()
        await expectFailure(error, from: &iterator)
    }

    @Test
    func bufferedSubscriberDrainsThenReceivesTerminalFailure() async {
        let hub = DisplayEventHub()
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("listener state lost")
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.windowClosed(WindowID(rawValue: 1)))
        hub.finish(throwing: error)

        await expectNext(.windowClosed(WindowID(rawValue: 1)), from: &iterator)
        await expectFailure(error, from: &iterator)
    }

    @Test
    func newInputSubscriptionAfterPipelineOverflowFailsImmediately() async {
        let hub = DisplayEventHub()
        let overflow = InputPipelineOverflow(
            stage: .rawInputQueue,
            capacity: InputPipelineCapacity(unchecked: 1)
        )
        let diagnostic = pipelineOverflowDiagnostic(overflow)
        let inputEvent = InputEvent(
            sequence: 1,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .diagnostic(diagnostic)
        )

        hub.publishInput(inputEvent)

        var inputIterator = hub.inputEvents().makeAsyncIterator()
        await expectFailure(.inputPipelineOverflow(overflow), from: &inputIterator)
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
                    stream: .displayEvents,
                    capacity: capacity
                )
        )
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

private func diagnosticInputEvent(sequence: UInt64, message: String) -> InputEvent {
    let diagnostic = cursorDiagnostic(message)
    return InputEvent(
        sequence: sequence,
        seatID: SeatID(rawValue: 2),
        target: .display,
        kind: .diagnostic(diagnostic)
    )
}

private func cursorDiagnostic(_ message: String) -> InputDiagnostic {
    InputDiagnostic(
        .cursor(.automaticPointerEnterFailed(.cursorApplication(message)))
    )
}

private func pipelineOverflowDiagnostic(_ overflow: InputPipelineOverflow) -> InputDiagnostic {
    InputDiagnostic(.inputPipelineOverflow(overflow))
}
