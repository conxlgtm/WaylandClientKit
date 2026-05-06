import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriteJobConcurrencyTests {
    @Test
    func concurrentWriteCallsOnSameJobOnlyOneWrites() throws {
        let sourceID = DataSourceID(rawValue: 30)
        let probe = ConcurrentSourceWriteProbe()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }
        let job = blockingWriteJob(
            sourceID: sourceID,
            descriptor: 600,
            probe: probe
        )

        writer.submit([job])

        #expect(probe.waitUntilStarted())
        #expect(
            job.write()
                == .failed(
                    sourceID: sourceID,
                    mimeType: .plainText,
                    error: .fileDescriptorAlreadyReleased
                )
        )

        probe.finish()
        #expect(
            waitForResults(from: writer)
                == [.succeeded(sourceID: sourceID, mimeType: .plainText)]
        )
        #expect(
            probe.writeCalls
                == [
                    ConcurrentSourceWriteProbe.WriteCall(
                        descriptor: 600,
                        bytes: Array("blocked".utf8)
                    )
                ]
        )
        #expect(probe.closedDescriptors == [600])
    }

    @Test
    func sameWriteJobSubmittedToTwoWritersOnlyWritesOnce() throws {
        let sourceID = DataSourceID(rawValue: 31)
        let probe = ConcurrentSourceWriteProbe()
        let firstWriter = ThreadedDataTransferSourceWriter()
        let secondWriter = ThreadedDataTransferSourceWriter()
        defer {
            firstWriter.shutdown()
            secondWriter.shutdown()
        }
        let job = blockingWriteJob(
            sourceID: sourceID,
            descriptor: 601,
            probe: probe
        )

        firstWriter.submit([job])
        #expect(probe.waitUntilStarted())
        secondWriter.submit([job])

        #expect(
            waitForResults(from: secondWriter)
                == [
                    .failed(
                        sourceID: sourceID,
                        mimeType: .plainText,
                        error: .fileDescriptorAlreadyReleased
                    )
                ]
        )

        probe.finish()
        #expect(
            waitForResults(from: firstWriter)
                == [.succeeded(sourceID: sourceID, mimeType: .plainText)]
        )
        #expect(probe.writeCalls.count == 1)
        #expect(probe.closedDescriptors == [601])
    }

    private func blockingWriteJob(
        sourceID: DataSourceID,
        descriptor: Int32,
        probe: ConcurrentSourceWriteProbe
    ) -> DataTransferSourceWriteJob {
        DataTransferSourceWriteJob(
            sourceID: sourceID,
            mimeType: .plainText,
            descriptor: descriptor,
            data: Data("blocked".utf8),
            prepareDescriptorForWriting: { _ in
                // No descriptor setup needed for deterministic concurrent write tests.
            },
            writeDescriptor: { descriptor, bytes in
                try probe.write(descriptor: descriptor, bytes: bytes)
            },
            closeDescriptor: { descriptor in
                probe.close(descriptor: descriptor)
            }
        )
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
}

private final class ConcurrentSourceWriteProbe: Sendable {
    struct WriteCall: Equatable, Sendable {
        let descriptor: Int32
        let bytes: [UInt8]
    }

    private let condition = NSCondition()
    private let state = Mutex(ConcurrentSourceWriteProbeState())

    var writeCalls: [WriteCall] {
        state.withLock(\.writeCalls)
    }

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    func write(descriptor: Int32, bytes: [UInt8]) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.writeCalls.append(WriteCall(descriptor: descriptor, bytes: bytes))
        }
        condition.broadcast()
        while !shouldFinish {
            condition.wait()
        }
        condition.unlock()

        return bytes.count
    }

    func close(descriptor: Int32) -> Int32 {
        condition.lock()
        state.withLock { storage in
            storage.closedDescriptors.append(descriptor)
        }
        condition.broadcast()
        condition.unlock()

        return 0
    }

    func finish() {
        condition.lock()
        state.withLock { storage in
            storage.shouldFinish = true
        }
        condition.broadcast()
        condition.unlock()
    }

    func waitUntilStarted() -> Bool {
        let deadline = Date(timeIntervalSinceNow: 2)
        condition.lock()
        defer { condition.unlock() }

        while writeCalls.isEmpty {
            guard condition.wait(until: deadline) else {
                return !writeCalls.isEmpty
            }
        }

        return true
    }

    private var shouldFinish: Bool {
        state.withLock(\.shouldFinish)
    }
}

private struct ConcurrentSourceWriteProbeState {
    var writeCalls: [ConcurrentSourceWriteProbe.WriteCall] = []
    var closedDescriptors: [Int32] = []
    var shouldFinish = false
}
