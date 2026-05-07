import Synchronization
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)
    private let offerHandle2 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0002)

    @Test
    func synchronizingSeatsBindsNewSeatsInStableOrder() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat2, seat1])
        #expect(backend.boundSeatIDs == [seat1, seat2])
        #expect(
            manager.seatSnapshots
                == [
                    DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .none)
                    ),
                    DataTransferSeatSnapshot(
                        seatID: seat2,
                        device: .bound(selection: .none)
                    ),
                ]
        )
    }

    @Test
    func synchronizingSameSeatsIsIdempotent() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([seat1])
        #expect(backend.boundSeatIDs == [seat1])
        #expect(backend.binding(for: seat1)?.releaseCount == 0)
    }

    @Test
    func synchronizingRemovedSeatsReleasesDataDevice() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat1, seat2])
        let firstBinding = try #require(backend.binding(for: seat1))

        try manager.synchronizeSeats([seat2])
        #expect(firstBinding.releaseCount == 1)
        #expect(manager.seatSnapshots.map(\.seatID) == [seat2])
        #expect(backend.binding(for: seat2)?.releaseCount == 0)
    }

    @Test
    func bindFailureKeepsAlreadyBoundSeats() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingSeatID = seat2
        let manager = DataTransferManager(backend: backend)

        #expect(throws: DataTransferError.unavailable) {
            try manager.synchronizeSeats([seat1, seat2])
        }
        #expect(backend.boundSeatIDs == [seat1, seat2])
        #expect(backend.binding(for: seat1)?.releaseCount == 0)
        #expect(
            manager.seatSnapshots
                == [
                    DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .none)
                    )
                ]
        )
    }

    @Test
    func dataDeviceSelectionClearWithoutCurrentSelectionIsNoOp() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        backend.binding(for: seat1)?.emit(.selection(nil))
        #expect(manager.selectionChanges.isEmpty)
    }

    @Test
    func selectionOfferAdoptionTracksMimeTypesAndPublishesSelection() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        offer.emit(.offer(MIMEType.plainTextUTF8.rawValue))
        device.emit(.selection(offerHandle1))

        #expect(
            manager.offerSnapshots
                == [
                    DataOfferSnapshot(
                        id: offer.id,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText, .plainTextUTF8]
                    )
                ]
        )
        #expect(
            manager.selectionChanges
                == [DataTransferSelectionChange(seatID: seat1, offerID: offer.id)]
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    )
                ]
        )
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func mimeTypeAfterSelectionUpdatesExistingOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        offer.emit(.offer(MIMEType.uriList.rawValue))

        #expect(manager.offerSnapshots.first?.mimeTypes == [.uriList])
    }

    @Test
    func replacingSelectionDestroysPreviousOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let firstOffer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        device.emit(.dataOffer(offerHandle2))
        let secondOffer = try #require(backend.offerBinding(for: offerHandle2))
        device.emit(.selection(offerHandle2))

        #expect(firstOffer.destroyCount == 1)
        #expect(secondOffer.destroyCount == 0)
        #expect(manager.offerSnapshots.map(\.id) == [secondOffer.id])
    }

    @Test
    func clearingSelectionDestroysCurrentOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        device.emit(.selection(nil))

        #expect(offer.destroyCount == 1)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(
            manager.selectionChanges
                == [
                    DataTransferSelectionChange(seatID: seat1, offerID: offer.id),
                    DataTransferSelectionChange(seatID: seat1, offerID: nil),
                ]
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: nil)
                    ),
                ]
        )
    }

    @Test
    func removingSeatDestroysPendingOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        try manager.synchronizeSeats([])

        #expect(offer.destroyCount == 1)
        #expect(manager.offerSnapshots.isEmpty)
    }

    @Test
    func selectingUnknownOfferReportsCallbackError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.selection(offerHandle1))

        #expect(throws: DataTransferError.unknownOffer) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func callbackErrorsAreStoredAndThrownOnNextOwnerThreadOperation() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([])
        let releasedBinding = try #require(backend.binding(for: seat1))

        releasedBinding.emit(.selection(nil))

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func callbackErrorsPreserveFirstFailure() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([])
        let releasedBinding = try #require(backend.binding(for: seat1))

        releasedBinding.emit(.selection(nil))
        releasedBinding.emit(.dataOffer(nil))

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }
}
