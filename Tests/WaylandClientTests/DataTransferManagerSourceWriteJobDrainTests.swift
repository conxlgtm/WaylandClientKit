import Foundation
import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceWriteJobDrainTests {
    private let seat1 = SeatID(rawValue: 1)

    @Test
    func drainSourceWriteJobsTransfersQueuedRequestsIntoSingleOwnerJobs() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 96),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptors.writeEnd)
        )

        let jobs = try manager.drainSourceWriteJobs()
        let job = try #require(jobs.first)

        #expect(jobs.count == 1)
        #expect(job.sourceID == source.id)
        #expect(job.mimeType == .plainText)
        #expect(job.data == Data("clipboard".utf8))
        #expect(backend.closedDescriptors.isEmpty)
        #expect(manager.drainSourceSendRequests().isEmpty)
        #expect(
            job.closeAsCancelled()
                == .failed(sourceID: source.id, mimeType: .plainText, error: .cancelled)
        )
        #expect(try readDescriptor.readData(limit: try ByteCount.bytes(32)).isEmpty)
    }

    @Test
    func drainedWriteJobDroppedWithoutSubmitClosesDescriptor() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        var readDescriptor = try OwnedFileDescriptor(adopting: descriptors.readEnd)

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 97),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptors.writeEnd)
        )

        do {
            let jobs = try manager.drainSourceWriteJobs()
            #expect(jobs.count == 1)
            #expect(manager.drainSourceSendRequests().isEmpty)
        }

        #expect(isClosedDescriptor(descriptors.writeEnd))
        try readDescriptor.close()
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

    private func isClosedDescriptor(_ descriptor: Int32) -> Bool {
        errno = 0
        let result = Glibc.fcntl(descriptor, F_GETFD)
        return result == -1 && errno == EBADF
    }
}
