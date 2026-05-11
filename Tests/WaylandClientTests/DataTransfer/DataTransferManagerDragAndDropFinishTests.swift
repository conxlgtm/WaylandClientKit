import Testing

@testable import WaylandClient
@testable import WaylandRaw

private let finishSeatID = SeatID(rawValue: 1)
private let finishOfferID = DataOfferID(rawValue: 1)
private let finishOfferHandle = RawDataOfferHandle(uncheckedRawValue: 0xDADA_1001)

@Suite
struct DataTransferManagerDragAndDropFinishTests {
    @Test
    func finishRejectsSelectedNoneAndDoesNotCallBinding() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.none))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsUnknownSelectedActionAndDoesNotCallBinding() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions(RawDataDeviceDNDAction(rawValue: 9)))
        offer.emit(.action(RawDataDeviceDNDAction(rawValue: 8)))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsSelectedAskUntilFinalActionChosen() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func askFinishUsesLastPreferredActionAfterDrop() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)
        try manager.setDragOfferActions(
            id: offer.id,
            actions: [.copy],
            preferredAction: .copy
        )

        try manager.finishDragOffer(id: offer.id)

        #expect(offer.finishCount == 1)
        #expect(offer.destroyCount == 1)
    }

    @Test
    func finishRejectsBeforeActionEventAndDoesNotCallBinding() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsBeforeDropAndDoesNotCallBinding() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsWithoutAcceptedMIMEAndDoesNotCallBinding() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsAfterPostDropActionRequestNone() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)
        try manager.apply(.dragActionsRequested(id: offer.id, preferredAction: .none))

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsWhenFinalPreferredActionIsAsk() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)
        try manager.apply(.dragActionsRequested(id: offer.id, preferredAction: .ask))

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsAfterNullAcceptAndDoesNotCallBinding() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: nil)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.accepts == [.init(serial: 1, mimeType: nil)])
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func finishRejectsAfterNullAcceptEvenIfMIMEAcceptedLater() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: nil)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(throws: DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(
            offer.accepts == [
                .init(serial: 1, mimeType: nil),
                .init(serial: 1, mimeType: .plainText),
            ]
        )
        #expect(try manager.dragOffer(id: offer.id).dragAndDrop?.acceptState == .rejected)
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func stateRejectsDragOfferSnapshotWithoutActiveSeat() throws {
        #expect(
            throws: DataTransferError.dragOfferNotActive(
                DragOfferIdentity(finishOfferID)
            )
        ) {
            _ = try DataTransferState(
                seats: [
                    finishSeatID: DataTransferSeatSnapshot(
                        seatID: finishSeatID,
                        device: .bound(selection: .none)
                    )
                ],
                offers: [
                    finishOfferID: try DataOfferSnapshot(
                        id: finishOfferID,
                        role: .dragAndDrop(seatID: finishSeatID),
                        mimeTypes: [.plainText]
                    )
                ]
            )
        }
    }

    @Test
    func stateRejectsActiveDragOfferWithoutEnterSerial() throws {
        #expect(
            throws: DataTransferError.dragOfferNotActive(
                DragOfferIdentity(finishOfferID)
            )
        ) {
            _ = try DataTransferState(
                seats: [
                    finishSeatID: DataTransferSeatSnapshot(
                        seatID: finishSeatID,
                        device: .bound(selection: .none),
                        dragAndDropOfferID: finishOfferID
                    )
                ],
                offers: [
                    finishOfferID: try DataOfferSnapshot(
                        id: finishOfferID,
                        role: .dragAndDrop(seatID: finishSeatID),
                        mimeTypes: [.plainText]
                    )
                ]
            )
        }
    }

    @Test
    func stateRejectsDroppedDragOfferWithoutEnterSerial() throws {
        #expect(
            throws: DataTransferError.dragOfferNotActive(
                DragOfferIdentity(finishOfferID)
            )
        ) {
            _ = try DataTransferState(
                seats: [
                    finishSeatID: DataTransferSeatSnapshot(
                        seatID: finishSeatID,
                        device: .bound(selection: .none),
                        dragAndDropOfferID: finishOfferID
                    )
                ],
                offers: [
                    finishOfferID: try DataOfferSnapshot(
                        id: finishOfferID,
                        role: .dragAndDrop(seatID: finishSeatID),
                        mimeTypes: [.plainText],
                        dragAndDrop: DragAndDropOfferMetadata(hasDropped: true)
                    )
                ]
            )
        }
    }
}

private func managerWithPendingDragOffer() throws -> (
    manager: DataTransferManager,
    device: RecordingDataTransferDeviceBinding,
    offer: RecordingDataTransferOfferBinding
) {
    let backend = RecordingDataTransferBackend()
    let manager = DataTransferManager(backend: backend)
    try manager.synchronizeSeats([finishSeatID])
    let device = try #require(backend.binding(for: finishSeatID))
    device.emit(.dataOffer(finishOfferHandle))
    let offer = try #require(backend.offerBinding(for: finishOfferHandle))
    offer.emit(.offer(MIMEType.plainText.rawValue))
    try manager.checkInvariantsForTesting()
    return (manager, device, offer)
}

private func enterDrag(manager: DataTransferManager) throws {
    let device = try #require(
        (manager.backend as? RecordingDataTransferBackend)?.binding(for: finishSeatID)
    )
    device.emit(.enter(dndEnter(offer: finishOfferHandle)))
    try manager.checkInvariantsForTesting()
}

private func dndEnter(offer: RawDataOfferHandle?) -> RawDataDeviceEnter {
    unsafe RawDataDeviceEnter(
        serial: 1,
        surface: nil,
        x: WaylandFixed(rawValue: 256),
        y: WaylandFixed(rawValue: 512),
        offer: offer,
        surfaceID: nil
    )
}
