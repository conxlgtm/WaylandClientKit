import Foundation
import Glibc
import Synchronization
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
        let cancellationThreadMarker = currentThreadMarker()
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
}

private func blockingWriteJob(
    sourceID: DataSourceID,
    descriptor: Int32,
    probe: SourceCancellationBackpressureProbe
) -> DataTransferSourceWriteJob {
    blockingWriteJob(source: .clipboard(sourceID), descriptor: descriptor, probe: probe)
}

private func blockingWriteJob(
    source: DataTransferSourceWriteSource,
    descriptor: Int32,
    probe: SourceCancellationBackpressureProbe
) -> DataTransferSourceWriteJob {
    DataTransferSourceWriteJob(
        source: source,
        mimeType: .plainText,
        descriptor: descriptor,
        data: Data("blocked".utf8),
        descriptorIO: DataTransferSourceDescriptorIO(
            prepareDescriptorForWriting: { _ in
                // No descriptor setup needed for this deterministic blocking test job.
            },
            writeDescriptor: { descriptor, bytes in
                try probe.write(descriptor: descriptor, bytes: bytes)
            },
            closeDescriptor: { descriptor in
                probe.close(descriptor: descriptor)
            }
        )
    )
}

private func queuedWriteJob(
    source: DataTransferSourceWriteSource,
    descriptor: Int32,
    closeRecorder: SourceCancellationCloseRecorder
) -> DataTransferSourceWriteJob {
    DataTransferSourceWriteJob(
        source: source,
        mimeType: .plainText,
        descriptor: descriptor,
        data: Data("queued".utf8),
        descriptorIO: DataTransferSourceDescriptorIO(
            prepareDescriptorForWriting: { _ in
                // No descriptor setup needed for this queued test job.
            },
            writeDescriptor: { _, bytes in bytes.count },
            closeDescriptor: { descriptor in
                closeRecorder.record(descriptor)
            }
        )
    )
}

private func verifyDrainedSourceCancelledEventCancelsInFlightWrite(
    source: DataTransferSourceWriteSource,
    event: DataTransferEvent,
    descriptor: Int32
) throws {
    let probe = SourceCancellationBackpressureProbe()
    let eventQueue = DataTransferEventQueue()
    let writer = ThreadedDataTransferSourceWriter()
    defer { writer.shutdown() }

    writer.submit([
        blockingWriteJob(source: source, descriptor: descriptor, probe: probe)
    ])
    #expect(probe.waitUntilStarted())
    eventQueue.append(event)

    DisplaySession.cancelSourceWrites(for: eventQueue.drain(), using: writer)

    #expect(
        waitForResults(from: writer)
            == [
                .failed(
                    source: source,
                    mimeType: .plainText,
                    error: .cancelled
                )
            ]
    )
    #expect(probe.closedDescriptors == [descriptor])
}

private func waitForResults(
    from writer: ThreadedDataTransferSourceWriter,
    count expectedCount: Int = 1
) -> [DataTransferSourceWriteResult] {
    var collectedResults: [DataTransferSourceWriteResult] = []
    for _ in 0..<1_000 {
        collectedResults.append(contentsOf: writer.drainResults())
        if collectedResults.count >= expectedCount {
            return collectedResults
        }

        usleep(1_000)
    }

    return collectedResults
}

private final class SourceCancellationBackpressureProbe: Sendable {
    private let condition = NSCondition()
    private let state = Mutex(SourceCancellationBackpressureProbeState())

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    var closeThreadMarkers: [ObjectIdentifier] {
        state.withLock(\.closeThreadMarkers)
    }

    func write(descriptor _: Int32, bytes _: ArraySlice<UInt8>) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.started = true
        }
        condition.broadcast()
        condition.unlock()

        throw DataTransferError.writeFileDescriptor(WaylandSystemErrno(unchecked: EAGAIN))
    }

    func close(descriptor: Int32) -> FileDescriptorCloseResult {
        condition.lock()
        state.withLock { storage in
            storage.closedDescriptors.append(descriptor)
            storage.closeThreadMarkers.append(currentThreadMarker())
        }
        condition.broadcast()
        condition.unlock()

        return .closed
    }

    func waitUntilStarted() -> Bool {
        let deadline = Date(timeIntervalSinceNow: 2)
        condition.lock()
        defer { condition.unlock() }

        while !started {
            guard condition.wait(until: deadline) else {
                return started
            }
        }

        return true
    }

    private var started: Bool {
        state.withLock(\.started)
    }
}

private struct SourceCancellationBackpressureProbeState {
    var started = false
    var closedDescriptors: [Int32] = []
    var closeThreadMarkers: [ObjectIdentifier] = []
}

private final class SourceCancellationCloseRecorder: Sendable {
    private let storage = Mutex<[Int32]>([])
    private let closeResult: Int32

    init(closeResult: Int32 = 0) {
        self.closeResult = closeResult
    }

    var descriptors: [Int32] {
        storage.withLock { $0 }
    }

    func record(_ descriptor: Int32) -> FileDescriptorCloseResult {
        storage.withLock { $0.append(descriptor) }
        return closeResult == 0
            ? .closed
            : .failed(WaylandSystemErrno(unchecked: closeResult > 0 ? closeResult : EIO))
    }
}

private func currentThreadMarker() -> ObjectIdentifier {
    ObjectIdentifier(Thread.current)
}
