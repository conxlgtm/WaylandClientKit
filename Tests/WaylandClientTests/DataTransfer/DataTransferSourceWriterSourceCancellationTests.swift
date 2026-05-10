import Glibc
import Testing

@testable import WaylandClient

@Suite
struct SourceWriterCancellationTests {
    @Test
    func cancelJobsForSourceClosesQueuedMatchingJobs() throws {
        let inFlightProbe = SourceCancellationBackpressureProbe()
        let matchingCloseRecorder = SourceCancellationCloseRecorder()
        let otherCloseRecorder = SourceCancellationCloseRecorder()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                sourceID: DataSourceID(rawValue: 25),
                descriptor: 505,
                probe: inFlightProbe
            )
        ])
        #expect(inFlightProbe.waitUntilStarted())
        writer.submit([
            queuedWriteJob(
                source: .clipboard(DataSourceID(rawValue: 26)),
                descriptor: 506,
                closeRecorder: matchingCloseRecorder
            ),
            queuedWriteJob(
                source: .primarySelection(DataSourceID(rawValue: 26)),
                descriptor: 507,
                closeRecorder: otherCloseRecorder
            ),
        ])

        writer.cancelJobs(for: .clipboard(DataSourceID(rawValue: 26)))

        #expect(matchingCloseRecorder.descriptors == [506])
        #expect(otherCloseRecorder.descriptors.isEmpty)
        #expect(
            writer.drainResults()
                == [
                    .failed(
                        source: .clipboard(DataSourceID(rawValue: 26)),
                        mimeType: .plainText,
                        error: .cancelled
                    )
                ]
        )

        writer.shutdown()
        #expect(otherCloseRecorder.descriptors == [507])
    }

    @Test
    func cancelJobsForSourceCancelsInFlightJobOnWorkerThread() throws {
        let sourceID = DataSourceID(rawValue: 28)
        let probe = SourceCancellationBackpressureProbe()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                source: .clipboard(sourceID),
                descriptor: 508,
                probe: probe
            )
        ])

        #expect(probe.waitUntilStarted())
        let cancellationThreadMarker = sourceCancellationThreadMarker()
        writer.cancelJobs(for: .clipboard(sourceID))

        #expect(
            waitForResults(from: writer)
                == [
                    .failed(
                        sourceID: sourceID,
                        mimeType: .plainText,
                        error: .cancelled
                    )
                ]
        )
        #expect(probe.closedDescriptors == [508])
        #expect(!probe.closeThreadMarkers.contains(cancellationThreadMarker))
    }

    @Test
    func cancelJobsForDifferentSourceDoesNotCancelInFlightJob() throws {
        let sourceID = DataSourceID(rawValue: 29)
        let probe = SourceCancellationBackpressureProbe()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                source: .clipboard(sourceID),
                descriptor: 509,
                probe: probe
            )
        ])

        #expect(probe.waitUntilStarted())
        writer.cancelJobs(for: .primarySelection(sourceID))
        usleep(10_000)

        #expect(probe.closedDescriptors.isEmpty)
        #expect(writer.drainResults().isEmpty)

        writer.shutdown()
        #expect(probe.closedDescriptors == [509])
        #expect(
            writer.drainResults()
                == [
                    .failed(
                        sourceID: sourceID,
                        mimeType: .plainText,
                        error: .cancelled
                    )
                ]
        )
    }
}

@Suite
struct SourceWriterDisplayCancellationTests {
    @Test
    func drainedSourceCancelledEventsCancelQueuedWritesForBothSourceKinds() throws {
        let inFlightProbe = SourceCancellationBackpressureProbe()
        let clipboardCloseRecorder = SourceCancellationCloseRecorder()
        let primaryCloseRecorder = SourceCancellationCloseRecorder()
        let eventQueue = DataTransferEventQueue()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                source: .clipboard(DataSourceID(rawValue: 30)),
                descriptor: 510,
                probe: inFlightProbe
            )
        ])
        #expect(inFlightProbe.waitUntilStarted())
        writer.submit([
            queuedWriteJob(
                source: .clipboard(DataSourceID(rawValue: 31)),
                descriptor: 511,
                closeRecorder: clipboardCloseRecorder
            ),
            queuedWriteJob(
                source: .primarySelection(DataSourceID(rawValue: 32)),
                descriptor: 512,
                closeRecorder: primaryCloseRecorder
            ),
        ])
        eventQueue.append(
            .clipboardSourceCancelled(
                ClipboardSourceIdentity(DataSourceID(rawValue: 31))
            )
        )
        eventQueue.append(
            .primarySelectionSourceCancelled(
                PrimarySelectionSourceIdentity(DataSourceID(rawValue: 32))
            )
        )

        DisplaySession.cancelSourceWrites(for: eventQueue.drain(), using: writer)

        #expect(clipboardCloseRecorder.descriptors == [511])
        #expect(primaryCloseRecorder.descriptors == [512])
        #expect(
            writer.drainResults()
                == [
                    .failed(
                        source: .clipboard(DataSourceID(rawValue: 31)),
                        mimeType: .plainText,
                        error: .cancelled
                    ),
                    .failed(
                        source: .primarySelection(DataSourceID(rawValue: 32)),
                        mimeType: .plainText,
                        error: .cancelled
                    ),
                ]
        )
    }

    @Test
    func drainedClipboardSourceCancelledEventCancelsInFlightWrite() throws {
        try verifyDrainedSourceCancelledEventCancelsInFlightWrite(
            source: .clipboard(DataSourceID(rawValue: 33)),
            event: .clipboardSourceCancelled(
                ClipboardSourceIdentity(DataSourceID(rawValue: 33))
            ),
            descriptor: 513
        )
    }

    @Test
    func drainedPrimarySelectionSourceCancelledEventCancelsInFlightWrite() throws {
        try verifyDrainedSourceCancelledEventCancelsInFlightWrite(
            source: .primarySelection(DataSourceID(rawValue: 34)),
            event: .primarySelectionSourceCancelled(
                PrimarySelectionSourceIdentity(DataSourceID(rawValue: 34))
            ),
            descriptor: 514
        )
    }

    @Test
    func sourceCancellationCloseFailureMapsToDiagnostic() throws {
        let inFlightProbe = SourceCancellationBackpressureProbe()
        let closeRecorder = SourceCancellationCloseRecorder(closeResult: EIO)
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                source: .clipboard(DataSourceID(rawValue: 35)),
                descriptor: 515,
                probe: inFlightProbe
            )
        ])
        #expect(inFlightProbe.waitUntilStarted())
        writer.submit([
            queuedWriteJob(
                source: .clipboard(DataSourceID(rawValue: 36)),
                descriptor: 516,
                closeRecorder: closeRecorder
            )
        ])

        writer.cancelJobs(for: .clipboard(DataSourceID(rawValue: 36)))

        let result = try #require(writer.drainResults().first)
        let diagnostic = try #require(DisplaySession.dataTransferDiagnostic(from: result))
        #expect(closeRecorder.descriptors == [516])
        #expect(
            diagnostic.source
                == .clipboard(ClipboardSourceIdentity(DataSourceID(rawValue: 36)))
        )
        #expect(diagnostic.mimeType == .plainText)
        #expect(diagnostic.operation == .sourceWriteFailed)
        #expect(
            diagnostic.error
                == .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
        )
    }

    @Test
    func drainedCancelledEventCollectsCloseFailureDiagnosticInSamePass() throws {
        try verifyDrainedCancelledEventCollectsCloseFailureDiagnosticInSamePass(
            source: .clipboard(DataSourceID(rawValue: 38)),
            event: .clipboardSourceCancelled(
                ClipboardSourceIdentity(DataSourceID(rawValue: 38))
            ),
            diagnosticSource: .clipboard(ClipboardSourceIdentity(DataSourceID(rawValue: 38)))
        )
    }

    @Test
    func drainedPrimarySelectionCancelledEventCollectsCloseFailureDiagnosticInSamePass() throws {
        try verifyDrainedCancelledEventCollectsCloseFailureDiagnosticInSamePass(
            source: .primarySelection(DataSourceID(rawValue: 39)),
            event: .primarySelectionSourceCancelled(
                PrimarySelectionSourceIdentity(DataSourceID(rawValue: 39))
            ),
            diagnosticSource: .primarySelection(
                PrimarySelectionSourceIdentity(DataSourceID(rawValue: 39))
            )
        )
    }
}

private func verifyDrainedCancelledEventCollectsCloseFailureDiagnosticInSamePass(
    source: DataTransferSourceWriteSource,
    event: DataTransferEvent,
    diagnosticSource: DataTransferDiagnosticSource
) throws {
    let inFlightSource = DataTransferSourceWriteSource.clipboard(DataSourceID(rawValue: 37))
    let queuedDescriptor: Int32 = 518
    let inFlightProbe = SourceCancellationBackpressureProbe()
    let closeRecorder = SourceCancellationCloseRecorder(closeResult: EIO)
    let writer = ThreadedDataTransferSourceWriter()
    var pendingDiagnostics: [DataTransferDiagnostic] = []
    defer { writer.shutdown() }

    writer.submit([
        blockingWriteJob(
            source: inFlightSource,
            descriptor: 517,
            probe: inFlightProbe
        )
    ])
    #expect(inFlightProbe.waitUntilStarted())
    writer.submit([
        queuedWriteJob(
            source: source,
            descriptor: queuedDescriptor,
            closeRecorder: closeRecorder
        )
    ])

    let drained = DisplaySession.drainDataTransferEventsAndDiagnostics(
        [event],
        using: writer,
        pendingDiagnostics: &pendingDiagnostics
    )

    #expect(drained.events == [event])
    #expect(closeRecorder.descriptors == [queuedDescriptor])
    #expect(pendingDiagnostics.isEmpty)
    #expect(
        drained.diagnostics
            == [
                DataTransferDiagnostic(
                    source: diagnosticSource,
                    mimeType: .plainText,
                    operation: .sourceWriteFailed,
                    error: .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
            ]
    )
}
