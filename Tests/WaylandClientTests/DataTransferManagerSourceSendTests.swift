import Foundation
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
}
