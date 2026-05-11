import Testing

@testable import WaylandClient
@testable import WaylandRaw

private let seat1 = SeatID(rawValue: 1)
private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)
private let offerHandle2 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0002)

@Suite
struct DataTransferManagerDragAndDropTests {
    @Test
    func dndEnterPublishesActiveDragOffer() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()

        try enterDrag(manager: manager, offer: offerHandle1)

        #expect(offer.destroyCount == 0)
        #expect(
            try manager.dragOffer(for: seat1)
                == DataOfferSnapshot(
                    id: offer.id,
                    role: .dragAndDrop(seatID: seat1),
                    mimeTypes: [.plainText],
                    dragAndDrop: DragAndDropOfferMetadata(enterSerial: 1)
                )
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragEntered(
                        DragEnterEvent(
                            seatID: seat1,
                            offerID: offer.id,
                            serial: 1,
                            location: DragLocation(x: 1, y: 2),
                            target: .focusless
                        )
                    )
                ]
        )
    }

    @Test
    func dndEnterPublishesManagedSurfaceTarget() throws {
        let windowID = WindowID(rawValue: 24)
        let surfaceID = RawObjectID(42)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(
            backend: backend
        ) { receivedSurfaceID in
            receivedSurfaceID == surfaceID ? .surface(.window(windowID)) : .unmanagedSurface
        }
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))

        device.emit(.enter(dndEnter(offer: offerHandle1, surfaceID: surfaceID)))

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragEntered(
                        DragEnterEvent(
                            seatID: seat1,
                            offerID: offer.id,
                            serial: 1,
                            location: DragLocation(x: 1, y: 2),
                            target: .surface(.window(windowID))
                        )
                    )
                ]
        )
    }

    @Test
    func dndOfferSourceActionsAndSelectedActionSurviveEnter() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()

        offer.emit(.sourceActions([.copy, .move]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager, offer: offerHandle1)

        #expect(
            try manager.dragOffer(for: seat1)?.dragAndDrop
                == DragAndDropOfferMetadata(
                    sourceActions: [.copy, .move],
                    selectedAction: .received(.copy),
                    enterSerial: 1
                )
        )
    }

    @Test
    func lateDndOfferMetadataPublishesOfferChange() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager, offer: offerHandle1)
        _ = manager.drainDataTransferEvents()

        offer.emit(.offer(MIMEType.uriList.rawValue))
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragOfferChanged(
                        DragOfferChangedEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .dragOfferChanged(
                        DragOfferChangedEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .dragOfferChanged(
                        DragOfferChangedEvent(seatID: seat1, offerID: offer.id)
                    ),
                ]
        )
        #expect(try manager.dragOffer(for: seat1)?.mimeTypes == [.plainText, .uriList])
        #expect(try manager.dragOffer(for: seat1)?.dragAndDrop?.sourceActions == [.copy, .ask])
        #expect(try manager.dragOffer(for: seat1)?.dragAndDrop?.selectedAction == .received(.ask))
    }

    @Test
    func dndMotionAndDropPublishForActiveOffer() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager, offer: offerHandle1)
        _ = manager.drainDataTransferEvents()

        device.emit(
            .motion(
                time: 44,
                x: WaylandFixed(rawValue: 768),
                y: WaylandFixed(rawValue: 1_280)
            )
        )
        device.emit(.drop)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragMotion(
                        DragMotionEvent(
                            seatID: seat1,
                            offerID: offer.id,
                            time: 44,
                            location: DragLocation(x: 3, y: 5)
                        )
                    ),
                    .dragDropped(DragDropEvent(seatID: seat1, offerID: offer.id)),
                ]
        )
        #expect(offer.destroyCount == 0)
    }

    @Test
    func dndLeavePublishesAndDestroysActiveOffer() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager, offer: offerHandle1)
        _ = manager.drainDataTransferEvents()

        device.emit(.leave)

        #expect(
            manager.drainDataTransferEvents()
                == [
                    .dragLeft(DragLeaveEvent(seatID: seat1, offerID: offer.id))
                ]
        )
        #expect(offer.destroyCount == 1)
        #expect(try manager.dragOffer(for: seat1) == nil)
    }

    @Test
    func newDndEnterDestroysPreviousActiveDragOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let firstOffer = try #require(backend.offerBinding(for: offerHandle1))
        firstOffer.emit(.offer(MIMEType.plainText.rawValue))
        try enterDrag(manager: manager, offer: offerHandle1)

        device.emit(.dataOffer(offerHandle2))
        let secondOffer = try #require(backend.offerBinding(for: offerHandle2))
        secondOffer.emit(.offer(MIMEType.uriList.rawValue))
        try enterDrag(manager: manager, offer: offerHandle2)

        #expect(firstOffer.destroyCount == 1)
        #expect(secondOffer.destroyCount == 0)
        #expect(try manager.dragOffer(for: seat1)?.id == secondOffer.id)
    }

    @Test
    func selectionOfferSurvivesUnrelatedDndLifecycle() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let selectionOffer = try #require(backend.offerBinding(for: offerHandle1))
        selectionOffer.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(offerHandle1))

        device.emit(.dataOffer(offerHandle2))
        let dragOffer = try #require(backend.offerBinding(for: offerHandle2))
        dragOffer.emit(.offer(MIMEType.uriList.rawValue))
        try enterDrag(manager: manager, offer: offerHandle2)
        device.emit(.leave)

        #expect(selectionOffer.destroyCount == 0)
        #expect(dragOffer.destroyCount == 1)
        #expect(try manager.selectionOffer(for: seat1)?.id == selectionOffer.id)
        #expect(try manager.dragOffer(for: seat1) == nil)
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
        try manager.checkInvariantsForTesting()

        device.emit(.enter(dndEnter(offer: offerHandle1)))

        #expect(
            manager.pendingCallbackError
                == DataTransferCallbackFailure(
                    context: .dataDevice(seat1),
                    error: .unknownDragOfferIdentity(DragOfferIdentity(selectionOffer.id))
                )
        )
    }

    @Test
    func seatRemovalDestroysActiveDragOffer() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        try enterDrag(manager: manager, offer: offerHandle1)

        try manager.synchronizeSeats([])

        #expect(offer.destroyCount == 1)
        #expect(manager.offerBindingsByID.isEmpty)
        #expect(manager.offerSnapshots.isEmpty)
    }
}

private func managerWithPendingDragOffer() throws -> (
    manager: DataTransferManager,
    device: RecordingDataTransferDeviceBinding,
    offer: RecordingDataTransferOfferBinding
) {
    let backend = RecordingDataTransferBackend()
    let manager = DataTransferManager(backend: backend)
    try manager.synchronizeSeats([seat1])
    let device = try #require(backend.binding(for: seat1))
    device.emit(.dataOffer(offerHandle1))
    let offer = try #require(backend.offerBinding(for: offerHandle1))
    offer.emit(.offer(MIMEType.plainText.rawValue))
    try manager.checkInvariantsForTesting()
    return (manager, device, offer)
}

private func enterDrag(
    manager: DataTransferManager,
    offer: RawDataOfferHandle
) throws {
    let device = try #require(
        (manager.backend as? RecordingDataTransferBackend)?.binding(for: seat1)
    )
    device.emit(.enter(dndEnter(offer: offer)))
    try manager.checkInvariantsForTesting()
}

private func dndEnter(offer: RawDataOfferHandle?) -> RawDataDeviceEnter {
    dndEnter(offer: offer, surfaceID: nil)
}

private func dndEnter(
    offer: RawDataOfferHandle?,
    surfaceID: RawObjectID?
) -> RawDataDeviceEnter {
    unsafe RawDataDeviceEnter(
        serial: 1,
        surface: nil,
        x: WaylandFixed(rawValue: 256),
        y: WaylandFixed(rawValue: 512),
        offer: offer,
        surfaceID: surfaceID
    )
}
