import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct DataTransferManagerDragAndDropTests {
    private let seat1 = SeatID(rawValue: 1)
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)
    private let offerHandle2 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0002)

    @Test
    func dndEnterDestroysUnsupportedOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))

        device.emit(.enter(dndEnter(offer: offerHandle1)))

        #expect(offer.destroyCount == 1)
        #expect(manager.offerBindingsByID.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(manager.selectionChanges.isEmpty)
    }

    @Test
    func dndLeaveKeepsUnsupportedOfferCleanupTerminal() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.enter(dndEnter(offer: offerHandle1)))
        device.emit(.leave)

        #expect(offer.destroyCount == 1)
        #expect(manager.offerBindingsByID.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
    }

    @Test
    func dndDropKeepsUnsupportedOfferCleanupTerminal() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.enter(dndEnter(offer: offerHandle1)))
        device.emit(.drop)

        #expect(offer.destroyCount == 1)
        #expect(manager.offerBindingsByID.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
    }

    @Test
    func repeatedDndOffersDoNotAccumulateBindings() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        for rawValue in UInt(1)...UInt(5) {
            let handle = dataOfferHandle(rawValue)
            device.emit(.dataOffer(handle))
            let offer = try #require(backend.offerBinding(for: handle))
            device.emit(.enter(dndEnter(offer: handle)))

            #expect(offer.destroyCount == 1)
            #expect(manager.offerBindingsByID.isEmpty)
            #expect(manager.offerSnapshots.isEmpty)
        }
    }

    @Test
    func selectionOfferSurvivesUnrelatedDndCleanup() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))

        device.emit(.dataOffer(offerHandle2))
        let dragOffer = try #require(backend.offerBinding(for: offerHandle2))
        device.emit(.enter(dndEnter(offer: offerHandle2)))
        device.emit(.leave)

        device.emit(.selection(offerHandle1))

        #expect(selectionOffer.destroyCount == 0)
        #expect(dragOffer.destroyCount == 1)
        #expect(
            manager.offerSnapshots
                == [
                    DataOfferSnapshot(
                        id: selectionOffer.id,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ]
        )
    }

    @Test
    func dndEnterWithCurrentSelectionHandleDoesNotDestroySelectionBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        device.emit(.enter(dndEnter(offer: offerHandle1)))

        #expect(selectionOffer.destroyCount == 0)
        #expect(
            manager.offerSnapshots
                == [
                    DataOfferSnapshot(
                        id: selectionOffer.id,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ]
        )
    }

    @Test
    func dndEnterWithCurrentSelectionHandleReportsTypedCallbackError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        device.emit(.enter(dndEnter(offer: offerHandle1)))

        #expect(throws: DataTransferError.unknownOffer) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func selectionReceiveStillWorksAfterRejectedDndEnter() throws {
        let backend = RecordingDataTransferBackend()
        backend.pipeDescriptors = DataTransferPipeDescriptors(readEnd: 20, writeEnd: 21)
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))
        device.emit(.enter(dndEnter(offer: offerHandle1)))

        #expect(throws: DataTransferError.unknownOffer) {
            try manager.throwPendingCallbackErrorIfAny()
        }
        var descriptor = try manager.receiveOffer(id: selectionOffer.id, mimeType: .plainText)
        let rawDescriptor = descriptor.releaseRawValue()

        #expect(rawDescriptor == 20)
        #expect(selectionOffer.destroyCount == 0)
        #expect(
            selectionOffer.receives
                == [
                    RecordingDataTransferOfferBinding.Receive(mimeType: .plainText, fd: 21)
                ]
        )
    }

    @Test
    func dndLeaveAndDropDoNotDestroySelectionOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        device.emit(.leave)
        device.emit(.drop)

        #expect(selectionOffer.destroyCount == 0)
        #expect(manager.offerSnapshots.map(\.id) == [selectionOffer.id])
    }

    @Test
    func seatRemovalStillDestroysPendingUnclassifiedOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))

        try manager.synchronizeSeats([])

        #expect(offer.destroyCount == 1)
        #expect(manager.offerBindingsByID.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
    }

    private func dataOfferHandle(_ rawValue: UInt) -> RawDataOfferHandle {
        RawDataOfferHandle(uncheckedRawValue: 0xDADA_1000 + rawValue)
    }

    private func dndEnter(offer: RawDataOfferHandle?) -> RawDataDeviceEnter {
        RawDataDeviceEnter(
            serial: 1,
            surface: nil,
            x: WaylandFixed(rawValue: 0),
            y: WaylandFixed(rawValue: 0),
            offer: offer
        )
    }
}
