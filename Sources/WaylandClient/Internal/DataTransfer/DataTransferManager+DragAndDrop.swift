import WaylandRaw

extension DataTransferManager {
    static func defaultTarget(for surfaceID: RawObjectID?) -> InputEventTarget {
        surfaceID == nil ? .focusless : .unmanagedSurface
    }

    func handleDragEnter(
        _ enter: RawDataDeviceEnter,
        seatID: SeatID
    ) throws {
        guard let handle = enter.offer else {
            return
        }
        let target = surfaceTargetResolver(enter.surfaceID)
        guard let offerID = store.offerID(for: handle) else {
            throw DataTransferError.unknownOfferHandle(rawValue: handle.rawValue, seatID: seatID)
        }
        let dragEntered = DataTransferAction.dragEntered(
            DataTransferDragEnterTransition(
                enter,
                seatID: seatID,
                offerID: offerID,
                target: target
            )
        )
        if let existingOffer = store.offerSnapshot(offerID) {
            guard case .dragAndDrop(seatID) = existingOffer.role else {
                throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
            }
            try apply(dragEntered)
            return
        }

        guard let runtimeOffer = store.runtimeOffer(offerID) else {
            throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
        }
        guard runtimeOffer.pendingSeatID == seatID else {
            throw DataTransferError.mismatchedOfferSeat(
                offer: .dragAndDrop(offerID.dragIdentity),
                expected: seatID,
                actual: runtimeOffer.pendingSeatID
            )
        }
        guard !runtimeOffer.pendingMIMETypes.isEmpty else {
            throw DataTransferError.emptyDataOffer
        }

        var actions: [DataTransferAction] = [
            .offerCreated(id: offerID, role: .dragAndDrop(seatID: seatID))
        ]
        actions.append(
            contentsOf: runtimeOffer.pendingMIMETypes.map { mimeType in
                .offerMimeType(id: offerID, mimeType: mimeType)
            }
        )
        actions.append(
            .offerSourceActions(id: offerID, actions: runtimeOffer.pendingSourceActions)
        )
        if let selectedAction = runtimeOffer.pendingSelectedAction {
            actions.append(.offerSelectedAction(id: offerID, action: selectedAction))
        }
        actions.append(dragEntered)
        try apply(actions, activatingOffers: [offerID])
    }
}
