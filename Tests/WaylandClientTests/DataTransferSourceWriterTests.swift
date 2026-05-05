import Foundation
import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceWriterTests {
    @Test
    func threadedWriterWritesDataAndRecordsSuccess() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 1),
                mimeType: .plainText,
                descriptor: descriptors.writeEnd,
                data: Data("clipboard".utf8)
            )
        ])

        let results = waitForResults(from: writer)
        let payload = try readDescriptor.readData(limit: try ByteCount.bytes(32))

        #expect(
            results == [
                .succeeded(sourceID: DataSourceID(rawValue: 1), mimeType: .plainText)
            ]
        )
        #expect(payload == Data("clipboard".utf8))
    }

    @Test
    func sourceWriteJobCannotWriteOrCloseSameDescriptorTwice() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let job = DataTransferSourceWriteJob(
            sourceID: DataSourceID(rawValue: 10),
            mimeType: .plainText,
            descriptor: descriptors.writeEnd,
            data: Data("clipboard".utf8)
        )

        #expect(
            job.closeAsCancelled()
                == .failed(
                    sourceID: DataSourceID(rawValue: 10),
                    mimeType: .plainText,
                    error: .cancelled
                )
        )
        #expect(
            job.write()
                == .failed(
                    sourceID: DataSourceID(rawValue: 10),
                    mimeType: .plainText,
                    error: .fileDescriptorAlreadyReleased
                )
        )
        #expect(try readDescriptor.readData(limit: try ByteCount.bytes(32)).isEmpty)
    }

    @Test
    func writerSubmittingSameJobTwiceDoesNotDoubleClose() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }
        let job = DataTransferSourceWriteJob(
            sourceID: DataSourceID(rawValue: 11),
            mimeType: .plainText,
            descriptor: descriptors.writeEnd,
            data: Data("clipboard".utf8)
        )

        writer.submit([job, job])

        #expect(
            waitForResults(from: writer, count: 2)
                == [
                    .succeeded(sourceID: DataSourceID(rawValue: 11), mimeType: .plainText),
                    .failed(
                        sourceID: DataSourceID(rawValue: 11),
                        mimeType: .plainText,
                        error: .fileDescriptorAlreadyReleased
                    ),
                ]
        )
        #expect(
            try readDescriptor.readData(limit: try ByteCount.bytes(32))
                == Data("clipboard".utf8)
        )
    }

    @Test
    func threadedWriterRecordsInvalidDescriptorFailure() {
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 2),
                mimeType: .plainText,
                descriptor: -1,
                data: Data("clipboard".utf8)
            )
        ])

        #expect(
            waitForResults(from: writer) == [
                .failed(
                    sourceID: DataSourceID(rawValue: 2),
                    mimeType: .plainText,
                    error: .invalidFileDescriptor(-1)
                )
            ]
        )
    }

    @Test
    func threadedWriterReportsClosedReaderAsWriteFailureWithoutSigpipeTermination() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        try readDescriptor.close()
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.submit([
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 4),
                mimeType: .plainText,
                descriptor: descriptors.writeEnd,
                data: Data("clipboard".utf8)
            )
        ])

        #expect(
            waitForResults(from: writer) == [
                .failed(
                    sourceID: DataSourceID(rawValue: 4),
                    mimeType: .plainText,
                    error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EPIPE))
                )
            ]
        )
    }

    @Test
    func threadedWriterClosesSubmittedJobsAfterShutdown() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let writer = ThreadedDataTransferSourceWriter()
        defer { writer.shutdown() }

        writer.shutdown()
        writer.submit([
            DataTransferSourceWriteJob(
                sourceID: DataSourceID(rawValue: 3),
                mimeType: .plainText,
                descriptor: descriptors.writeEnd,
                data: Data("clipboard".utf8)
            )
        ])

        let payload = try readDescriptor.readData(limit: try ByteCount.bytes(32))

        #expect(
            writer.drainResults() == [
                .failed(
                    sourceID: DataSourceID(rawValue: 3),
                    mimeType: .plainText,
                    error: .cancelled
                )
            ]
        )
        #expect(payload.isEmpty)
    }

    @Test
    func submittingSameJobAfterShutdownClosesDescriptorOnce() throws {
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)
        let writer = ThreadedDataTransferSourceWriter()
        let job = DataTransferSourceWriteJob(
            sourceID: DataSourceID(rawValue: 12),
            mimeType: .plainText,
            descriptor: descriptors.writeEnd,
            data: Data("clipboard".utf8)
        )

        writer.shutdown()
        writer.submit([job, job])

        #expect(
            writer.drainResults()
                == [
                    .failed(
                        sourceID: DataSourceID(rawValue: 12),
                        mimeType: .plainText,
                        error: .cancelled
                    ),
                    .failed(
                        sourceID: DataSourceID(rawValue: 12),
                        mimeType: .plainText,
                        error: .fileDescriptorAlreadyReleased
                    ),
                ]
        )
        #expect(try readDescriptor.readData(limit: try ByteCount.bytes(32)).isEmpty)
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
}
