import Testing

@testable import WaylandClient
@testable import WaylandRaw

private let cleanupSeatID = SeatID(rawValue: 1)
private let cleanupOfferHandle = RawDataOfferHandle(uncheckedRawValue: 0xDADA_2001)

@Suite
struct DataTransferManagerDragAndDropCleanupTests {
    @Test
    func cancelAfterNullAcceptDestroysOfferAndClearsActiveDragOffer() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: nil)
        device.emit(.drop)

        try manager.cancelDragOffer(id: offer.id)

        #expect(offer.accepts == [.init(serial: 1, mimeType: nil)])
        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 1)
        #expect(try manager.dragOffer(for: cleanupSeatID) == nil)
    }

    @Test
    func cancelDismissesAskOfferAfterDrop() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))
        try enterDrag(manager: manager)
        device.emit(.drop)

        try manager.cancelDragOffer(id: offer.id)

        #expect(offer.finishCount == 0)
        #expect(offer.destroyCount == 1)
        #expect(try manager.dragOffer(for: cleanupSeatID) == nil)
    }

    @Test
    func cancelledDragOfferCannotReceiveOrSetActions() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: nil)
        device.emit(.drop)
        try manager.cancelDragOffer(id: offer.id)

        #expect(
            throws: DataTransferError.unknownDragOfferIdentity(DragOfferIdentity(offer.id))
        ) {
            _ = try manager.receiveDragOffer(id: offer.id, mimeType: .plainText)
        }
        #expect(
            throws: DataTransferError.unknownDragOfferIdentity(DragOfferIdentity(offer.id))
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.copy],
                preferredAction: .copy
            )
        }
    }

    @Test
    func motionAfterDropDoesNotPublish() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager)
        _ = manager.drainDataTransferEvents()
        device.emit(.drop)
        _ = manager.drainDataTransferEvents()

        device.emit(
            .motion(
                time: 44,
                x: WaylandFixed(rawValue: 768),
                y: WaylandFixed(rawValue: 1_280)
            )
        )

        #expect(manager.drainDataTransferEvents().isEmpty)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func duplicateDropDoesNotPublishDuplicateEvent() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager)
        _ = manager.drainDataTransferEvents()
        device.emit(.drop)
        _ = manager.drainDataTransferEvents()

        device.emit(.drop)

        #expect(manager.drainDataTransferEvents().isEmpty)
        #expect(offer.destroyCount == 0)
    }

    @Test
    func leaveAfterDropDoesNotDestroyOfferBeforeFinish() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        _ = manager.drainDataTransferEvents()
        device.emit(.drop)
        _ = manager.drainDataTransferEvents()

        device.emit(.leave)

        #expect(manager.drainDataTransferEvents().isEmpty)
        #expect(offer.destroyCount == 0)
        #expect(try manager.dragOffer(for: cleanupSeatID)?.id == offer.id)

        try manager.finishDragOffer(id: offer.id)
        #expect(offer.finishCount == 1)
        #expect(offer.destroyCount == 1)
    }
}

private func managerWithPendingDragOffer() throws -> (
    manager: DataTransferManager,
    device: RecordingDataTransferDeviceBinding,
    offer: RecordingDataTransferOfferBinding
) {
    let backend = RecordingDataTransferBackend()
    let manager = DataTransferManager(backend: backend)
    try manager.synchronizeSeats([cleanupSeatID])
    let device = try #require(backend.binding(for: cleanupSeatID))
    device.emit(.dataOffer(cleanupOfferHandle))
    let offer = try #require(backend.offerBinding(for: cleanupOfferHandle))
    offer.emit(.offer(MIMEType.plainText.rawValue))
    try manager.checkInvariantsForTesting()
    return (manager, device, offer)
}

private func enterDrag(manager: DataTransferManager) throws {
    let device = try #require(
        (manager.backend as? RecordingDataTransferBackend)?.binding(for: cleanupSeatID)
    )
    device.emit(.enter(dndEnter(offer: cleanupOfferHandle)))
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
