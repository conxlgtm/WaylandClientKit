import Foundation
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
        let descriptor: Int32 = 309

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
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptor)
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
        #expect(backend.closedDescriptors == [descriptor])
    }

    @Test
    func drainedWriteJobDroppedWithoutSubmitClosesDescriptor() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptor: Int32 = 312

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
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptor)
        )

        do {
            let jobs = try manager.drainSourceWriteJobs()
            #expect(jobs.count == 1)
            #expect(manager.drainSourceSendRequests().isEmpty)
        }

        #expect(backend.closedDescriptors == [descriptor])
    }

    @Test
    func drainSourceWriteJobsPreservesBackendWriteFailure() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptor: Int32 = 310
        backend.failingWriteDescriptors[descriptor] = .writeFileDescriptor(
            WaylandSystemErrno(unchecked: EIO)
        )

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 98),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: descriptor))

        let jobs = try manager.drainSourceWriteJobs()
        let job = try #require(jobs.first)

        #expect(
            job.write()
                == .failed(
                    sourceID: source.id,
                    mimeType: .plainText,
                    error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
        )
        #expect(backend.closedDescriptors == [descriptor])
        #expect(backend.descriptorWrites.isEmpty)
    }

    @Test
    func drainSourceWriteJobsPreservesBackendCloseFailure() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptor: Int32 = 311
        backend.failingCloseDescriptors[descriptor] = EIO

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 99),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: descriptor))

        let jobs = try manager.drainSourceWriteJobs()
        let job = try #require(jobs.first)

        #expect(
            job.write()
                == .failed(
                    sourceID: source.id,
                    mimeType: .plainText,
                    error: .closeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
        )
        #expect(
            backend.descriptorWrites
                == [
                    RecordingDataTransferBackend.DescriptorWrite(
                        descriptor: descriptor,
                        bytes: Array("clipboard".utf8)
                    )
                ]
        )
        #expect(backend.closedDescriptors == [descriptor])
    }
}
