import Glibc
import Testing

@testable import WaylandClient

@Suite
struct SourceWriterDisplayDrainPublicationTests {
    @Test
    func displayDrainIncludesSuccessfulSourceWriteEvents() {
        let writer = ThreadedDataTransferSourceWriter()
        var pendingDiagnostics: [DataTransferDiagnostic] = []
        defer { writer.shutdown() }

        writer.submit([
            queuedWriteJob(
                source: .clipboard(DataSourceID(rawValue: 37)),
                descriptor: 517,
                closeRecorder: SourceCancellationCloseRecorder()
            )
        ])

        var drained = DataTransferDrain(events: [], diagnostics: [])
        for _ in 0..<1_000 {
            drained = DisplaySession.drainDataTransferEventsAndDiagnostics(
                [],
                using: writer,
                pendingDiagnostics: &pendingDiagnostics
            )
            if !drained.events.isEmpty {
                break
            }
            usleep(1_000)
        }

        #expect(
            drained.events
                == [
                    .sourceWriteSucceeded(
                        DataTransferSourceTransferEvent(
                            source: ClipboardSourceIdentity(DataSourceID(rawValue: 37)),
                            mimeType: .plainText
                        )
                    )
                ]
        )
        #expect(drained.diagnostics.isEmpty)
    }

    @Test
    func displayCorePublishesDrainedDiagnosticsBeforeDataTransferEvents() async {
        let inFlightProbe = SourceCancellationBackpressureProbe()
        let closeRecorder = SourceCancellationCloseRecorder(closeResult: EIO)
        let writer = ThreadedDataTransferSourceWriter()
        var pendingDiagnostics: [DataTransferDiagnostic] = []
        let cancellationEvent = DataTransferEvent.clipboardSourceCancelled(
            ClipboardSourceIdentity(DataSourceID(rawValue: 38))
        )
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                source: .clipboard(DataSourceID(rawValue: 37)),
                descriptor: 517,
                probe: inFlightProbe
            )
        ])
        #expect(inFlightProbe.waitUntilStarted())
        writer.submit([
            queuedWriteJob(
                source: .clipboard(DataSourceID(rawValue: 38)),
                descriptor: 518,
                closeRecorder: closeRecorder
            )
        ])

        let drained = DisplaySession.drainDataTransferEventsAndDiagnostics(
            [cancellationEvent],
            using: writer,
            pendingDiagnostics: &pendingDiagnostics
        )
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        var dataTransferIterator = hub.dataTransferEvents().makeAsyncIterator()
        var diagnosticsIterator = hub.diagnostics().makeAsyncIterator()

        core.publishDataTransferDrain(drained)

        let expectedDiagnostic = DisplayDiagnostic(
            id: DiagnosticID(rawValue: 1),
            severity: .degraded,
            payload: .dataTransfer(
                DataTransferDiagnostic(
                    source: ClipboardSourceIdentity(DataSourceID(rawValue: 38)),
                    mimeType: .plainText,
                    operation: .sourceWriteFailed,
                    error: .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
            )
        )
        await expectSourceWriterDisplayEvent(
            .diagnostic(expectedDiagnostic),
            from: &displayIterator
        )
        await expectSourceWriterDiagnostic(expectedDiagnostic, from: &diagnosticsIterator)
        await expectSourceWriterDataTransfer(cancellationEvent, from: &dataTransferIterator)
    }
}

private func expectSourceWriterDataTransfer(
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

private func expectSourceWriterDisplayEvent(
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

private func expectSourceWriterDiagnostic(
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
