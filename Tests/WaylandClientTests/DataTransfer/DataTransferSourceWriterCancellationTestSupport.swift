import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

func blockingWriteJob(
    sourceID: DataSourceID,
    descriptor: Int32,
    probe: SourceCancellationBackpressureProbe
) -> DataTransferSourceWriteJob {
    blockingWriteJob(source: .clipboard(sourceID), descriptor: descriptor, probe: probe)
}

func blockingWriteJob(
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

func queuedWriteJob(
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

func verifyDrainedSourceCancelledEventCancelsInFlightWrite(
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

func waitForResults(
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

final class SourceCancellationBackpressureProbe: Sendable {
    private let condition = NSCondition()
    private let state = Mutex(SourceCancellationBackpressureProbeState())

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    var closeThreadMarkers: [ObjectIdentifier] {
        state.withLock(\.closeThreadMarkers)
    }

    var writeAttemptCount: Int {
        state.withLock(\.writeAttemptCount)
    }

    @safe
    func write(descriptor _: Int32, bytes _: UnsafeRawBufferPointer) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.started = true
            storage.writeAttemptCount += 1
        }
        condition.broadcast()
        condition.unlock()

        throw DataTransferError.writeFileDescriptor(WaylandSystemErrno(unchecked: EAGAIN))
    }

    func close(descriptor: Int32) -> FileDescriptorCloseResult {
        condition.lock()
        state.withLock { storage in
            storage.closedDescriptors.append(descriptor)
            storage.closeThreadMarkers.append(sourceCancellationThreadMarker())
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

    func waitUntilWriteAttemptCount(atLeast minimumCount: Int) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 2)
        condition.lock()
        defer { condition.unlock() }

        while writeAttemptCount < minimumCount {
            guard condition.wait(until: deadline) else {
                return writeAttemptCount >= minimumCount
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
    var writeAttemptCount = 0
    var closedDescriptors: [Int32] = []
    var closeThreadMarkers: [ObjectIdentifier] = []
}

final class SourceCancellationCloseRecorder: Sendable {
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

func sourceCancellationThreadMarker() -> ObjectIdentifier {
    ObjectIdentifier(Thread.current)
}
