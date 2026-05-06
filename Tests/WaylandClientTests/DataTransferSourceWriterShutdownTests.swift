import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriterShutdownTests {
    @Test
    func shutdownCancelsInFlightJobAndWaitsForWorker() throws {
        let probe = BlockingSourceWriteProbe()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                sourceID: DataSourceID(rawValue: 20),
                descriptor: 500,
                probe: probe
            )
        ])

        #expect(probe.waitUntilStarted())
        writer.shutdown()

        let results = writer.drainResults()
        #expect(probe.closedDescriptors == [500])
        #expect(
            results == [
                .failed(
                    sourceID: DataSourceID(rawValue: 20),
                    mimeType: .plainText,
                    error: .cancelled
                )
            ]
        )
        #expect(writer.drainResults().isEmpty)
    }

    @Test
    func shutdownCancelsQueuedAndInFlightJobs() throws {
        let inFlightProbe = BlockingSourceWriteProbe()
        let queuedCloseRecorder = WriterDescriptorCloseRecorder()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                sourceID: DataSourceID(rawValue: 21),
                descriptor: 501,
                probe: inFlightProbe
            ),
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 22),
                mimeType: .plainText,
                descriptor: 502,
                data: Data("queued".utf8),
                prepareDescriptorForWriting: { _ in
                    // No descriptor setup needed for this queued test job.
                },
                writeDescriptor: { _, bytes in bytes.count },
                closeDescriptor: { descriptor in
                    queuedCloseRecorder.record(descriptor)
                    return 0
                }
            ),
        ])

        #expect(inFlightProbe.waitUntilStarted())
        writer.shutdown()

        let results = writer.drainResults()
        #expect(inFlightProbe.closedDescriptors == [501])
        #expect(queuedCloseRecorder.descriptors == [502])
        #expect(results.count == 2)
        #expect(
            results.contains(
                .failed(
                    sourceID: DataSourceID(rawValue: 21),
                    mimeType: .plainText,
                    error: .cancelled
                )
            )
        )
        #expect(
            results.contains(
                .failed(
                    sourceID: DataSourceID(rawValue: 22),
                    mimeType: .plainText,
                    error: .cancelled
                )
            )
        )
    }

    @Test
    func shutdownReportsInFlightCloseFailure() throws {
        let probe = BlockingSourceWriteProbe(closeResult: EIO)
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            blockingWriteJob(
                sourceID: DataSourceID(rawValue: 23),
                descriptor: 503,
                probe: probe
            )
        ])

        #expect(probe.waitUntilStarted())
        writer.shutdown()

        #expect(probe.closedDescriptors == [503])
        #expect(
            writer.drainResults()
                == [
                    .failed(
                        sourceID: DataSourceID(rawValue: 23),
                        mimeType: .plainText,
                        error: .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                    )
                ]
        )
    }

    private func blockingWriteJob(
        sourceID: DataSourceID,
        descriptor: Int32,
        probe: BlockingSourceWriteProbe
    ) -> DataTransferSourceWriteJob {
        DataTransferSourceWriteJob(
            sourceID: sourceID,
            mimeType: .plainText,
            descriptor: descriptor,
            data: Data("blocked".utf8),
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
    }
}

private final class BlockingSourceWriteProbe: Sendable {
    private let condition = NSCondition()
    private let state = Mutex(BlockingSourceWriteProbeState())
    private let closeResult: Int32

    init(closeResult: Int32 = 0) {
        self.closeResult = closeResult
    }

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    func write(descriptor _: Int32, bytes _: [UInt8]) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.started = true
        }
        condition.broadcast()
        while !shouldUnblock {
            condition.wait()
        }
        condition.unlock()

        throw DataTransferError.cancelled
    }

    func close(descriptor: Int32) -> Int32 {
        condition.lock()
        state.withLock { storage in
            storage.closedDescriptors.append(descriptor)
            storage.shouldUnblock = true
        }
        condition.broadcast()
        condition.unlock()

        return closeResult
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

    private var shouldUnblock: Bool {
        state.withLock(\.shouldUnblock)
    }
}

private struct BlockingSourceWriteProbeState {
    var started = false
    var shouldUnblock = false
    var closedDescriptors: [Int32] = []
}

private final class WriterDescriptorCloseRecorder: Sendable {
    private let storage = Mutex<[Int32]>([])

    var descriptors: [Int32] {
        storage.withLock { $0 }
    }

    func record(_ descriptor: Int32) {
        storage.withLock { $0.append(descriptor) }
    }
}
