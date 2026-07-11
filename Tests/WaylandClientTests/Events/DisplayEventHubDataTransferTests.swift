import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubDataTransferTests {
    @Test
    func dataTransferStreamReceivesPublishedEvents() async {
        let hub = DisplayEventHub()
        var iterator = hub.dataTransferEvents().makeAsyncIterator()
        let event = DataTransferEvent.clipboardSelectionChanged(
            ClipboardSelectionEvent(
                seatID: SeatID(rawValue: 1),
                offerID: DataOfferID(rawValue: 2)
            )
        )

        hub.publishDataTransfer(event)

        await expectDataTransferNext(event, from: &iterator)
    }

    @Test
    func diagnosticsStreamsReceiveDataTransferDiagnostics() async {
        let hub = DisplayEventHub()
        let diagnostic = DataTransferDiagnostic(
            source: ClipboardSourceIdentity(DataSourceID(rawValue: 1)),
            mimeType: .plainText,
            operation: .sourceWriteFailed,
            error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        hub.publishDataTransferDiagnostic(diagnostic)

        let expectedDiagnostic = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .dataTransfer(diagnostic)
        )
        await expectDataTransferDisplayNext(
            .diagnostic(expectedDiagnostic),
            from: &displayIterator
        )
        await expectDataTransferDiagnosticNext(
            expectedDiagnostic,
            from: &diagnosticsIterator
        )
    }

    @Test
    func sourceWriteFailureResultMapsToDiagnostic() {
        let diagnostic = DisplaySession.dataTransferDiagnostic(
            from: .failed(
                sourceID: DataSourceID(rawValue: 2),
                mimeType: .plainTextUTF8,
                error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
            )
        )

        #expect(
            diagnostic
                == DataTransferDiagnostic(
                    source: ClipboardSourceIdentity(DataSourceID(rawValue: 2)),
                    mimeType: .plainTextUTF8,
                    operation: .sourceWriteFailed,
                    error: .writeFileDescriptor(
                        WaylandSystemErrno(unchecked: EIO)
                    )
                )
        )
    }

    @Test
    func primarySelectionSourceWriteFailureResultMapsToDiagnostic() {
        let diagnostic = DisplaySession.dataTransferDiagnostic(
            from: .failed(
                source: .primarySelection(DataSourceID(rawValue: 5)),
                mimeType: .plainTextUTF8,
                error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
            )
        )

        #expect(
            diagnostic
                == DataTransferDiagnostic(
                    source: .primarySelection(
                        PrimarySelectionSourceIdentity(DataSourceID(rawValue: 5))
                    ),
                    mimeType: .plainTextUTF8,
                    operation: .sourceWriteFailed,
                    error: .writeFileDescriptor(
                        WaylandSystemErrno(unchecked: EIO)
                    )
                )
        )
    }

    @Test
    func sourceWriteSuccessResultDoesNotMapToDiagnostic() {
        #expect(
            DisplaySession.dataTransferDiagnostic(
                from: .succeeded(sourceID: DataSourceID(rawValue: 3), mimeType: .plainText)
            ) == nil
        )
    }

    @Test
    func cancelledSourceWriteResultDoesNotMapToDiagnostic() {
        #expect(
            DisplaySession.dataTransferDiagnostic(
                from: .failed(
                    sourceID: DataSourceID(rawValue: 3),
                    mimeType: .plainText,
                    error: .cancelled
                )
            ) == nil
        )
    }

    @Test
    func sourceWriteFailureDiagnosticPublishesThroughDisplayCore() async {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let diagnostic = DataTransferDiagnostic(
            source: ClipboardSourceIdentity(DataSourceID(rawValue: 4)),
            mimeType: .plainText,
            operation: .sourceWriteFailed,
            error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        )
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        core.publishDataTransferDiagnostics([diagnostic])

        let expectedDiagnostic = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .dataTransfer(diagnostic)
        )
        await expectDataTransferDisplayNext(
            .diagnostic(expectedDiagnostic),
            from: &displayIterator
        )
        await expectDataTransferDiagnosticNext(
            expectedDiagnostic,
            from: &diagnosticsIterator
        )
    }

    @Test
    func dataTransferSubscriberOverflowUsesConfiguredCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: try EventStreamConfiguration(dataTransferEventCapacity: 1)
        )
        let stream = hub.dataTransferEvents()
        var iterator = stream.makeAsyncIterator()

        hub.publishDataTransfer(
            .clipboardSourceCancelled(ClipboardSourceIdentity(DataSourceID(rawValue: 1)))
        )
        hub.publishDataTransfer(
            .clipboardSourceCancelled(ClipboardSourceIdentity(DataSourceID(rawValue: 2)))
        )

        do {
            _ = try await iterator.next()
            Issue.record("Expected configured data transfer event overflow")
        } catch {
            #expect(
                error
                    == .eventSubscriberOverflow(
                        stream: .dataTransferEvents,
                        capacity: 1
                    )
            )
        }
    }

    @Test
    func fatalInternalInvariantTerminatesDataTransferStream() async {
        let hub = DisplayEventHub()
        var iterator = hub.dataTransferEvents().makeAsyncIterator()
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("listener state lost")
        )

        hub.finish(throwing: error)

        await expectFailure(error, from: &iterator)
    }
}

private func expectDataTransferNext(
    _ expectedEvent: DataTransferEvent,
    from iterator: inout DataTransferEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected data transfer event, got \(error)")
    }
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

private func expectDataTransferDisplayNext(
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

private func expectDataTransferDiagnosticNext(
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
