import Synchronization
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerTests {  // swiftlint:disable:this type_body_length
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
    func failedInitialBindingPreparationLeavesStoreEmpty() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingSeatID = seat1
        let manager = DataTransferManager(backend: backend)

        #expect(throws: DataTransferError.unavailable) {
            try manager.synchronizeSeats([seat1])
        }

        #expect(manager.seatSnapshots.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(manager.drainDataTransferEvents().isEmpty)
        try manager.checkInvariantsForTesting()
    }

    @Test
    func dataDeviceSelectionClearWithoutCurrentSelectionIsNoOp() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        backend.binding(for: seat1)?.emit(.selection(nil))
        #expect(manager.drainDataTransferEvents().isEmpty)
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
                    try DataOfferSnapshot(
                        id: offer.id,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText, .plainTextUTF8]
                    )
                ]
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .clipboardSelectionChanged(
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
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        offer.emit(.offer(MIMEType.uriList.rawValue))

        #expect(manager.offerSnapshots.first?.mimeTypes == [.plainText, .uriList])
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .clipboardSelectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .clipboardSelectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    ),
                ]
        )
    }

    @Test
    func malformedRemoteMIMETypeIsIgnored() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer("UTF8_STRING"))
        offer.emit(.offer(" text/plain "))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        #expect(manager.pendingCallbackError == nil)
        #expect(manager.offerSnapshots.first?.mimeTypes == [.plainText])
    }

    @Test
    func replacingSelectionDestroysPreviousOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let firstOffer = try #require(backend.offerBinding(for: offerHandle1))
        firstOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        device.emit(.dataOffer(offerHandle2))
        let secondOffer = try #require(backend.offerBinding(for: offerHandle2))
        secondOffer.emit(.offer(MIMEType.plainTextUTF8.rawValue))
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
        offer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        device.emit(.selection(nil))

        #expect(offer.destroyCount == 1)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .clipboardSelectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .clipboardSelectionChanged(
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
    func pendingOfferIDsForSeatAreStable() {
        var store = DataTransferStore()
        let firstOfferID = DataOfferID(rawValue: 1)
        let secondOfferID = DataOfferID(rawValue: 2)

        store.insertPendingOffer(
            handle: offerHandle2,
            offerID: secondOfferID,
            binding: RecordingDataTransferOfferBinding(id: secondOfferID) { _ in
                // Test does not need offer callbacks.
            },
            seatID: seat1
        )
        store.insertPendingOffer(
            handle: offerHandle1,
            offerID: firstOfferID,
            binding: RecordingDataTransferOfferBinding(id: firstOfferID) { _ in
                // Test does not need offer callbacks.
            },
            seatID: seat1
        )

        #expect(store.pendingOfferIDs(for: seat1) == [firstOfferID, secondOfferID])
    }

    @Test
    func selectingUnknownOfferReportsCallbackError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.selection(offerHandle1))

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .unknownOfferHandle(rawValue: offerHandle1.rawValue, seatID: seat1)
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataDevice(seat1),
                error: .unknownOfferHandle(rawValue: offerHandle1.rawValue, seatID: seat1)
            )
        ) {
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

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .unknownSeat(seat1)
                )
        )
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataDevice(seat1),
                error: .unknownSeat(seat1)
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }
}
