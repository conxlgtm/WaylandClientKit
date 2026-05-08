import Foundation
import Glibc
import Synchronization
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriterShutdownTests {
    @Test
    func shutdownCancelsInFlightJobAndWaitsForWorker() throws {
        let probe = BackpressureSourceWriteProbe()
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
        let shutdownThreadMarker = currentThreadMarker()
        writer.shutdown()

        let results = writer.drainResults()
        #expect(probe.closedDescriptors == [500])
        #expect(!probe.closeThreadMarkers.contains(shutdownThreadMarker))
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
        let inFlightProbe = BackpressureSourceWriteProbe()
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
                    return .closed
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
        let probe = BackpressureSourceWriteProbe(closeResult: EIO)
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

    @Test
    func shutdownCancelsBackpressuredNonblockingPipeWriteFromWorkerThread() throws {
        let descriptors = try makePipeDescriptors()
        var writeEndOwnedByTest = true
        defer {
            _ = Glibc.close(descriptors.readEnd)
            if writeEndOwnedByTest {
                _ = Glibc.close(descriptors.writeEnd)
            }
        }
        try fillPipeUntilWouldBlock(descriptors.writeEnd)
        let probe = PipeWriteProbe()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 24),
                mimeType: .plainText,
                descriptor: descriptors.writeEnd,
                data: Data("blocked".utf8),
                writeDescriptor: { descriptor, bytes in
                    try probe.write(descriptor: descriptor, bytes: bytes)
                },
                closeDescriptor: { descriptor in
                    probe.close(descriptor: descriptor)
                }
            )
        ])
        writeEndOwnedByTest = false

        #expect(probe.waitUntilStarted())
        let shutdownThreadMarker = currentThreadMarker()
        writer.shutdown()

        #expect(
            writer.drainResults()
                == [
                    .failed(
                        sourceID: DataSourceID(rawValue: 24),
                        mimeType: .plainText,
                        error: .cancelled
                    )
                ]
        )
        #expect(probe.closedDescriptors == [descriptors.writeEnd])
        #expect(!probe.closeThreadMarkers.contains(shutdownThreadMarker))
    }

    private func blockingWriteJob(
        sourceID: DataSourceID,
        descriptor: Int32,
        probe: BackpressureSourceWriteProbe
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

private final class BackpressureSourceWriteProbe: Sendable {
    private let condition = NSCondition()
    private let state = Mutex(BackpressureSourceWriteProbeState())
    private let closeResult: Int32

    init(closeResult: Int32 = 0) {
        self.closeResult = closeResult
    }

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    var closeThreadMarkers: [ObjectIdentifier] {
        state.withLock(\.closeThreadMarkers)
    }

    func write(descriptor _: Int32, bytes _: [UInt8]) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.started = true
            storage.writeCallCount += 1
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

        return closeResult == 0
            ? .closed
            : .failed(WaylandSystemErrno(unchecked: closeResult > 0 ? closeResult : EIO))
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

private struct BackpressureSourceWriteProbeState {
    var started = false
    var writeCallCount = 0
    var closedDescriptors: [Int32] = []
    var closeThreadMarkers: [ObjectIdentifier] = []
}

private final class PipeWriteProbe: Sendable {
    private let condition = NSCondition()
    private let state = Mutex(PipeWriteProbeState())

    var closedDescriptors: [Int32] {
        state.withLock(\.closedDescriptors)
    }

    var closeThreadMarkers: [ObjectIdentifier] {
        state.withLock(\.closeThreadMarkers)
    }

    func write(descriptor: Int32, bytes: [UInt8]) throws -> Int {
        condition.lock()
        state.withLock { storage in
            storage.started = true
            storage.writeCallCount += 1
        }
        condition.broadcast()
        condition.unlock()

        let result = unsafe bytes.withUnsafeBytes { buffer in
            unsafe Glibc.write(descriptor, buffer.baseAddress, buffer.count)
        }
        guard result >= 0 else {
            throw DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
            )
        }

        return result
    }

    func close(descriptor: Int32) -> FileDescriptorCloseResult {
        condition.lock()
        state.withLock { storage in
            storage.closedDescriptors.append(descriptor)
            storage.closeThreadMarkers.append(currentThreadMarker())
        }
        condition.broadcast()
        condition.unlock()

        return .posixReturn(Glibc.close(descriptor))
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

private struct PipeWriteProbeState {
    var started = false
    var writeCallCount = 0
    var closedDescriptors: [Int32] = []
    var closeThreadMarkers: [ObjectIdentifier] = []
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

private func makePipeDescriptors() throws -> (readEnd: Int32, writeEnd: Int32) {
    var descriptors = [Int32](repeating: -1, count: 2)
    let result = unsafe descriptors.withUnsafeMutableBufferPointer { descriptorBuffer in
        unsafe Glibc.pipe(descriptorBuffer.baseAddress)
    }
    guard result == 0 else {
        throw DataTransferError.createPipe(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }

    return (readEnd: descriptors[0], writeEnd: descriptors[1])
}

private func fillPipeUntilWouldBlock(_ descriptor: Int32) throws {
    try setNonblocking(descriptor)
    let bytes = [UInt8](repeating: 0, count: 4_096)
    while true {
        let result = unsafe bytes.withUnsafeBytes { buffer in
            unsafe Glibc.write(descriptor, buffer.baseAddress, buffer.count)
        }
        if result >= 0 {
            continue
        }
        if errno == EAGAIN || errno == EWOULDBLOCK {
            return
        }

        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }
}

private func setNonblocking(_ descriptor: Int32) throws {
    let flags = Glibc.fcntl(descriptor, F_GETFL)
    guard flags >= 0 else {
        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }
    guard Glibc.fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw DataTransferError.writeFileDescriptor(
            WaylandSystemErrno(unchecked: errno > 0 ? errno : EIO)
        )
    }
}

private func currentThreadMarker() -> ObjectIdentifier {
    ObjectIdentifier(Thread.current)
}
