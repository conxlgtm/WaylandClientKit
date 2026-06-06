import Testing

@testable import WaylandClient
@testable import WaylandRaw

private let requestSeatID = SeatID(rawValue: 1)
private let requestOfferHandle = RawDataOfferHandle(uncheckedRawValue: 0xDADA_1001)

@Suite
struct DataTransferManagerDragAndDropRequestTests {
    @Test
    func dragOfferRequestsMapToBindingRequests() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .move]))
        offer.emit(.action(.move))
        try enterDrag(manager: manager)

        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        try manager.setDragOfferActions(
            id: offer.id,
            actions: [.copy, .move],
            preferredAction: .move
        )
        let device = try #require(
            (manager.backend as? RecordingDataTransferBackend)?.binding(for: requestSeatID)
        )
        device.emit(.drop)
        try manager.finishDragOffer(id: offer.id)

        #expect(offer.accepts == [.init(serial: 1, mimeType: .plainText)])
        #expect(
            offer.actionRequests
                == [.init(actions: [.copy, .move], preferredAction: .move)]
        )
        #expect(offer.finishCount == 1)
        #expect(offer.destroyCount == 1)
    }

    @Test
    func dragOfferActionRequestRejectsUnavailablePreferredAction() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        try enterDrag(manager: manager)

        #expect(
            throws: DataTransferError.unsupportedDragAction(
                action: .move,
                available: [.copy]
            )
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.copy],
                preferredAction: .move
            )
        }
        #expect(offer.actionRequests.isEmpty)
    }

    @Test
    func dragOfferActionRequestRejectsPreferredActionMissingFromSourceActions() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        try enterDrag(manager: manager)

        #expect(
            throws: DataTransferError.unsupportedDragAction(
                action: .move,
                available: [.copy]
            )
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.copy, .move],
                preferredAction: .move
            )
        }
        #expect(offer.actionRequests.isEmpty)
    }

    @Test
    func dragOfferActionRequestRejectsUnknownOutgoingActionBits() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        try enterDrag(manager: manager)

        #expect(throws: DataTransferError.invalidDragActionSet(rawValue: 8)) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: DragActionSet(rawValue: 8),
                preferredAction: .none
            )
        }
        #expect(offer.actionRequests.isEmpty)
    }

    @Test
    func dragOfferActionRequestRejectsUnknownPreferredAction() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        try enterDrag(manager: manager)

        #expect(throws: DataTransferError.invalidDragAction(rawValue: 8)) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.copy],
                preferredAction: .unknown(rawValue: 8)
            )
        }
        #expect(offer.actionRequests.isEmpty)
    }

    @Test
    func dragOfferActionNegotiationRejectsVersionBelowThree() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.protocolVersion = 2
        try enterDrag(manager: manager)

        #expect(
            throws: DataTransferError.dragActionNegotiationUnavailable(
                DragOfferIdentity(offer.id)
            )
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.copy],
                preferredAction: .copy
            )
        }
        #expect(
            throws: DataTransferError.dragActionNegotiationUnavailable(
                DragOfferIdentity(offer.id)
            )
        ) {
            try manager.finishDragOffer(id: offer.id)
        }
        #expect(offer.actionRequests.isEmpty)
        #expect(offer.finishCount == 0)
    }

    @Test
    func setActionsAfterDropForCopyMoveIsRejected() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy]))
        offer.emit(.action(.copy))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(
            throws: DataTransferError.dragActionRequestNotAllowed(
                DragOfferIdentity(offer.id)
            )
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [],
                preferredAction: .none
            )
        }
        #expect(offer.actionRequests.isEmpty)

        try manager.finishDragOffer(id: offer.id)
        #expect(offer.finishCount == 1)
    }

    @Test
    func setActionsAfterDropForAskRequiresFinalTransferAction() throws {
        let (manager, device, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions([.copy, .ask]))
        offer.emit(.action(.ask))
        try enterDrag(manager: manager)
        try manager.acceptDragOffer(id: offer.id, mimeType: .plainText)
        device.emit(.drop)

        #expect(
            throws: DataTransferError.dragActionRequestNotAllowed(
                DragOfferIdentity(offer.id)
            )
        ) {
            try manager.setDragOfferActions(
                id: offer.id,
                actions: [.ask],
                preferredAction: .ask
            )
        }
        #expect(offer.actionRequests.isEmpty)
    }

    @Test
    func unknownRemoteDragActionsArePreserved() throws {
        let (manager, _, offer) = try managerWithPendingDragOffer()
        offer.emit(.sourceActions(RawDataDeviceDNDAction(rawValue: 9)))
        offer.emit(.action(RawDataDeviceDNDAction(rawValue: 8)))
        try enterDrag(manager: manager)

        let metadata = try #require(manager.dragOffer(for: requestSeatID)?.dragAndDrop)
        #expect(metadata.sourceActions == DragActionSet(rawValue: 9))
        #expect(metadata.selectedAction == .received(.unknown(rawValue: 8)))
        #expect(manager.pendingCallbackError == nil)
    }
}

private func managerWithPendingDragOffer() throws -> (
    manager: DataTransferManager,
    device: RecordingDataTransferDeviceBinding,
    offer: RecordingDataTransferOfferBinding
) {
    let backend = RecordingDataTransferBackend()
    let manager = DataTransferManager(backend: backend)
    try manager.synchronizeSeats([requestSeatID])
    let device = try #require(backend.binding(for: requestSeatID))
    device.emit(.dataOffer(requestOfferHandle))
    let offer = try #require(backend.offerBinding(for: requestOfferHandle))
    offer.emit(.offer(MIMEType.plainText.rawValue))
    try manager.checkInvariantsForTesting()
    return (manager, device, offer)
}

private func enterDrag(manager: DataTransferManager) throws {
    let device = try #require(
        (manager.backend as? RecordingDataTransferBackend)?.binding(for: requestSeatID)
    )
    device.emit(.enter(dndEnter(offer: requestOfferHandle)))
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
