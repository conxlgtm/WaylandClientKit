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
        if let offerID = store.offerID(for: handle) {
            try enterExistingDragOffer(
                offerID,
                event: enter,
                seatID: seatID,
                target: target
            )
            return
        }

        let claimedOffer = try selectionEngine.takePendingOfferForDrag(
            handle: handle,
            seatID: seatID
        )
        try enterClaimedDragOffer(
            claimedOffer,
            handle: handle,
            event: enter,
            seatID: seatID,
            target: target
        )
    }

    private func enterExistingDragOffer(
        _ offerID: DataOfferID,
        event: RawDataDeviceEnter,
        seatID: SeatID,
        target: InputEventTarget
    ) throws {
        guard let existingOffer = store.offerSnapshot(offerID),
            case .dragAndDrop(seatID) = existingOffer.role
        else {
            throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
        }
        try apply(
            .dragEntered(
                DataTransferDragEnterTransition(
                    event,
                    seatID: seatID,
                    offerID: offerID,
                    target: target
                )
            )
        )
    }

    private func enterClaimedDragOffer(
        _ claimedOffer: SelectionEngineClaimedOffer,
        handle: RawDataOfferHandle,
        event: RawDataDeviceEnter,
        seatID: SeatID,
        target: InputEventTarget
    ) throws {
        guard let binding = claimedOffer.binding as? any DataTransferOfferBinding else {
            selectionEngine.restoreClaimedOffer(claimedOffer)
            preconditionFailure("clipboard offer is not backed by a data-device offer")
        }
        let offerID = claimedOffer.id
        let pendingMetadata =
            pendingDragMetadataByOfferID.removeValue(forKey: offerID)
            ?? PendingDragOfferMetadata()
        store.insertPendingOffer(
            handle: handle,
            offerID: offerID,
            binding: binding,
            seatID: seatID
        )
        do {
            try restoreClaimedOfferMetadata(
                claimedOffer,
                pendingMetadata: pendingMetadata
            )
            try apply(
                dragActivationActions(
                    claimedOffer,
                    event: event,
                    pendingMetadata: pendingMetadata,
                    target: target
                ),
                activatingOffers: [offerID]
            )
        } catch {
            _ = store.removeOffer(offerID)
            pendingDragMetadataByOfferID[offerID] = pendingMetadata
            selectionEngine.restoreClaimedOffer(claimedOffer)
            throw error
        }
    }

    private func restoreClaimedOfferMetadata(
        _ claimedOffer: SelectionEngineClaimedOffer,
        pendingMetadata: PendingDragOfferMetadata
    ) throws {
        for mimeType in claimedOffer.mimeTypes {
            try store.appendPendingMIMEType(mimeType, offerID: claimedOffer.id)
        }
        try store.setPendingSourceActions(
            pendingMetadata.sourceActions,
            offerID: claimedOffer.id
        )
        if let selectedAction = pendingMetadata.selectedAction {
            try store.setPendingSelectedAction(selectedAction, offerID: claimedOffer.id)
        }
    }

    private func dragActivationActions(
        _ claimedOffer: SelectionEngineClaimedOffer,
        event: RawDataDeviceEnter,
        pendingMetadata: PendingDragOfferMetadata,
        target: InputEventTarget
    ) -> [DataTransferAction] {
        var actions: [DataTransferAction] = [
            .dragOfferCreated(id: claimedOffer.id, seatID: claimedOffer.seatID)
        ]
        actions.append(
            contentsOf: claimedOffer.mimeTypes.map { mimeType in
                .offerMimeType(id: claimedOffer.id, mimeType: mimeType)
            }
        )
        actions.append(
            .offerSourceActions(
                id: claimedOffer.id,
                actions: pendingMetadata.sourceActions
            )
        )
        if let selectedAction = pendingMetadata.selectedAction {
            actions.append(.offerSelectedAction(id: claimedOffer.id, action: selectedAction))
        }
        actions.append(
            .dragEntered(
                DataTransferDragEnterTransition(
                    event,
                    seatID: claimedOffer.seatID,
                    offerID: claimedOffer.id,
                    target: target
                )
            )
        )
        return actions
    }
}
