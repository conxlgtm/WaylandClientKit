import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerSelectionTests {
    private let seat1 = SeatID(rawValue: 1)
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_1001)

    @Test
    func selectionOfferReturnsCurrentSelectionSnapshot() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        #expect(
            try manager.selectionOffer(for: seat1)
                == (try DataOfferSnapshot(
                    id: offer.id,
                    role: .selection(seatID: seat1),
                    mimeTypes: [.plainText]
                ))
        )
    }

    @Test
    func selectionOfferIgnoresDragActionMetadataCallbacks() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        _ = manager.drainDataTransferEvents()

        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))

        #expect(manager.pendingCallbackError == nil)
        #expect(manager.drainDataTransferEvents().isEmpty)
        #expect(
            try manager.selectionOffer(for: seat1)
                == (try DataOfferSnapshot(
                    id: offer.id,
                    role: .selection(seatID: seat1),
                    mimeTypes: [.plainText]
                ))
        )
    }

    @Test
    func selectionWithNoMimeTypesRecordsCallbackError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        device.emit(.selection(offerHandle1))

        #expect(manager.offerSnapshots.isEmpty)
        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .emptyDataOffer
                )
        )
    }

    @Test
    func selectionOfferReturnsNilWhenSeatHasNoSelection() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        #expect(try manager.selectionOffer(for: seat1) == nil)
    }

    @Test
    func selectionOfferRejectsUnknownSeat() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            try manager.selectionOffer(for: seat1)
        }
    }

    @Test
    func selectionOfferRejectsSeatWithoutDataDevice() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        manager.store.replaceState(
            try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .unbound
                    )
                ]
            )
        )

        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            try manager.selectionOffer(for: seat1)
        }
    }
}
