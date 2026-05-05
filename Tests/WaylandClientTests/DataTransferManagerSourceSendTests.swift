import Foundation
import Glibc
import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceSendTests {
    private let seat1 = SeatID(rawValue: 1)

    @Test
    func sourceSendWithProviderQueuesOwnedSendRequestWithoutClosingDescriptor() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 90),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 210))

        try manager.throwPendingCallbackErrorIfAny()
        #expect(backend.closedDescriptors.isEmpty)

        let requests = manager.drainSourceSendRequests()
        let request = try #require(requests.first)

        #expect(requests.count == 1)
        #expect(request.sourceID == source.id)
        #expect(request.mimeType == .plainText)
        #expect(request.data == Data("clipboard".utf8))

        try request.close()
        #expect(backend.closedDescriptors == [210])
    }

    @Test
    func sourceSendRequestReleaseTransfersDescriptorWithoutClosing() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 91),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 211))

        do {
            let requests = manager.drainSourceSendRequests()
            let request = try #require(requests.first)
            let releasedDescriptor = try request.releaseRawDescriptor()

            #expect(releasedDescriptor == 211)
        }

        #expect(backend.closedDescriptors.isEmpty)
    }

    @Test
    func sourceSendRequestWriteWritesDataAndClosesDescriptor() throws {
        let backend = RecordingDataTransferBackend()
        let request = try queuedSourceSendRequest(
            descriptor: 214,
            data: Data("clipboard".utf8),
            backend: backend
        )

        try request.write()

        #expect(
            backend.descriptorWrites == [
                RecordingDataTransferBackend.DescriptorWrite(
                    descriptor: 214,
                    bytes: Array("clipboard".utf8)
                )
            ]
        )
        #expect(backend.closedDescriptors == [214])
    }

    @Test
    func sourceSendRequestWriteHandlesPartialWrites() throws {
        let backend = RecordingDataTransferBackend()
        backend.maximumWriteByteCount = 4
        let request = try queuedSourceSendRequest(
            descriptor: 215,
            data: Data("clipboard".utf8),
            backend: backend
        )

        try request.write()

        #expect(
            backend.descriptorWrites == [
                .init(descriptor: 215, bytes: Array("clip".utf8)),
                .init(descriptor: 215, bytes: Array("boar".utf8)),
                .init(descriptor: 215, bytes: Array("d".utf8)),
            ]
        )
        #expect(backend.closedDescriptors == [215])
    }

    @Test
    func sourceSendRequestWriteClosesDescriptorOnWriteFailure() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingWriteDescriptors[216] = .writeFileDescriptor(
            WaylandSystemErrno(unchecked: EIO)
        )
        let request = try queuedSourceSendRequest(
            descriptor: 216,
            data: Data("clipboard".utf8),
            backend: backend
        )

        #expect(
            throws: DataTransferError.writeFileDescriptor(
                WaylandSystemErrno(unchecked: EIO)
            )
        ) {
            try request.write()
        }
        #expect(backend.closedDescriptors == [216])
    }

    @Test
    func sourceSendRequestWriteReportsCloseFailureAfterSuccessfulWrite() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingCloseDescriptors[217] = EIO
        let request = try queuedSourceSendRequest(
            descriptor: 217,
            data: Data("clipboard".utf8),
            backend: backend
        )

        #expect(
            throws: DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: EIO)
            )
        ) {
            try request.write()
        }
        #expect(
            backend.descriptorWrites == [
                .init(descriptor: 217, bytes: Array("clipboard".utf8))
            ]
        )
    }

    @Test
    func sourceSendRequestWriteClosesEmptyPayloadWithoutWriting() throws {
        let backend = RecordingDataTransferBackend()
        let request = try queuedSourceSendRequest(
            descriptor: 218,
            data: Data(),
            backend: backend
        )

        try request.write()

        #expect(backend.descriptorWrites.isEmpty)
        #expect(backend.closedDescriptors == [218])
    }

    @Test
    func sourceCancellationClosesUndrainedSendRequests() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 92),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 212))
        sourceBinding.emit(.cancelled)

        #expect(backend.closedDescriptors == [212])
        #expect(manager.drainSourceSendRequests().isEmpty)
        #expect(
            manager.drainDataTransferEvents()
                == [.sourceCancelled(ClipboardSourceIdentity(source.id))]
        )
    }

    @Test
    func replacingSelectionSourceClosesUndrainedSendRequests() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let first = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 93),
            dataProvider: DataTransferSourceProvider(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let firstBinding = try #require(backend.sourceBinding(for: first.id))

        firstBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 213))
        _ = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.uriList],
            serial: InputSerial(rawValue: 94),
            dataProvider: DataTransferSourceProvider(data: [.uriList: Data("file://a".utf8)])
        )

        #expect(backend.closedDescriptors == [213])
        #expect(manager.drainSourceSendRequests().isEmpty)
    }

    private func queuedSourceSendRequest(
        descriptor: Int32,
        data: Data,
        backend: RecordingDataTransferBackend
    ) throws -> DataTransferSourceSendRequest {
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 95),
            dataProvider: DataTransferSourceProvider(data: [.plainText: data])
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: descriptor))
        try manager.throwPendingCallbackErrorIfAny()

        let requests = manager.drainSourceSendRequests()
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        return request
    }
}
