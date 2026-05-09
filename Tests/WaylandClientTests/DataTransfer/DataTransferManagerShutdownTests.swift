import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerShutdownTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offerHandle = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)

    @Test
    func shutdownReleasesDataTransferResourcesOnOwnerThread() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat1, seat2])
        let source = try manager.setSelectionSource(
            seatID: seat1,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 90),
            payloads: sourcePayloads(for: [.plainText])
        )
        try #require(backend.sourceBinding(for: source.id)).emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: 78)
        )
        let remoteDevice = try #require(backend.binding(for: seat2))
        remoteDevice.emit(.dataOffer(offerHandle))
        let offerBinding = try #require(backend.offerBinding(for: offerHandle))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        remoteDevice.emit(.selection(offerHandle))
        _ = manager.drainDataTransferEvents()

        manager.shutdown()

        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        let firstDevice = try #require(backend.binding(for: seat1))
        let secondDevice = try #require(backend.binding(for: seat2))

        #expect(firstDevice.releaseCount == 1)
        #expect(secondDevice.releaseCount == 1)
        #expect(sourceBinding.destroyCount == 1)
        #expect(offerBinding.destroyCount == 1)
        #expect(backend.closedDescriptors == [78])
        #expect(manager.seatSnapshots.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(manager.drainSourceSendRequests().isEmpty)
        #expect(manager.drainDataTransferEvents().isEmpty)
    }
}
