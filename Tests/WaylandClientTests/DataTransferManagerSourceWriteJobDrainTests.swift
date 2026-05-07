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
        let descriptor: Int32 = 309

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 96),
            payloads: DataTransferSourcePayloadSet(
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
            payloads: DataTransferSourcePayloadSet(
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
    func drainSourceWriteJobsPreparesDescriptorForNonblockingWrite() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        let flagsDescriptor = Glibc.dup(descriptors.writeEnd)
        #expect(flagsDescriptor >= 0)
        defer {
            _ = Glibc.close(descriptors.readEnd)
            _ = Glibc.close(descriptors.writeEnd)
            _ = Glibc.close(flagsDescriptor)
        }
        let descriptor = descriptors.writeEnd
        backend.prepareSourceDescriptorForWriting = { descriptor in
            try setNonblocking(descriptor)
        }

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 100),
            payloads: DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: descriptor))

        let jobs = try manager.drainSourceWriteJobs()
        let job = try #require(jobs.first)

        #expect(
            job.write()
                == .succeeded(sourceID: source.id, mimeType: .plainText)
        )
        let flags = Glibc.fcntl(flagsDescriptor, F_GETFL)
        #expect(flags >= 0)
        #expect((flags & O_NONBLOCK) == O_NONBLOCK)
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

    @Test
    func drainSourceWriteJobsPreservesInjectedWriteFailure() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        defer {
            _ = Glibc.close(descriptors.readEnd)
            _ = Glibc.close(descriptors.writeEnd)
        }
        backend.failingWriteDescriptors[descriptors.writeEnd] = .writeFileDescriptor(
            WaylandSystemErrno(unchecked: EIO)
        )

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 101),
            payloads: DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptors.writeEnd)
        )

        let job = try #require(try manager.drainSourceWriteJobs().first)

        #expect(
            job.write()
                == .failed(
                    sourceID: source.id,
                    mimeType: .plainText,
                    error: .writeFileDescriptor(WaylandSystemErrno(unchecked: EIO))
                )
        )
        #expect(backend.closedDescriptors == [descriptors.writeEnd])
        #expect(backend.descriptorWrites.isEmpty)
    }

    @Test
    func drainSourceWriteJobsPreservesInjectedCloseFailure() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        defer {
            _ = Glibc.close(descriptors.readEnd)
            _ = Glibc.close(descriptors.writeEnd)
        }
        backend.failingCloseDescriptors[descriptors.writeEnd] = EIO

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 102),
            payloads: DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptors.writeEnd)
        )

        let job = try #require(try manager.drainSourceWriteJobs().first)

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
                        descriptor: descriptors.writeEnd,
                        bytes: Array("clipboard".utf8)
                    )
                ]
        )
        #expect(backend.closedDescriptors == [descriptors.writeEnd])
    }

    @Test
    func drainSourceWriteJobsPreservesInjectedPartialWrites() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let descriptors = try makePipeDescriptors()
        defer {
            _ = Glibc.close(descriptors.readEnd)
            _ = Glibc.close(descriptors.writeEnd)
        }
        backend.maximumWriteByteCount = 4

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 103),
            payloads: DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: descriptors.writeEnd)
        )

        let job = try #require(try manager.drainSourceWriteJobs().first)

        #expect(
            job.write()
                == .succeeded(sourceID: source.id, mimeType: .plainText)
        )
        #expect(
            backend.descriptorWrites
                == [
                    RecordingDataTransferBackend.DescriptorWrite(
                        descriptor: descriptors.writeEnd,
                        bytes: Array("clip".utf8)
                    ),
                    RecordingDataTransferBackend.DescriptorWrite(
                        descriptor: descriptors.writeEnd,
                        bytes: Array("boar".utf8)
                    ),
                    RecordingDataTransferBackend.DescriptorWrite(
                        descriptor: descriptors.writeEnd,
                        bytes: Array("d".utf8)
                    ),
                ]
        )
        #expect(backend.closedDescriptors == [descriptors.writeEnd])
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
