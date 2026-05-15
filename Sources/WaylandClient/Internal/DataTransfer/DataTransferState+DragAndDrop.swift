extension DataTransferState {
    mutating func applyDragAndDrop(_ action: DataTransferAction) throws -> [DataTransferEffect] {
        switch action {
        case .offerSourceActions(let id, let actions):
            return try applyOfferSourceActions(id: id, actions: actions)
        case .offerSelectedAction(let id, let action):
            return try applyOfferSelectedAction(id: id, action: action)
        case .dragAccepted(let id, let mimeType):
            return try applyDragAccepted(id: id, mimeType: mimeType)
        case .dragActionsRequested(let id, let preferredAction):
            return try applyDragActionsRequested(id: id, preferredAction: preferredAction)
        case .dragEntered(let enter):
            return try applyDragEntered(enter)
        case .dragMotion(let seatID, let time, let location):
            return try applyDragMotion(seatID: seatID, time: time, location: location)
        case .dragLeft(let seatID):
            return applyDragLeft(seatID)
        case .dragDropped(let seatID):
            return try applyDragDropped(seatID)
        case .dragFinished(let offerID), .dragCancelled(let offerID):
            return applyDragFinished(offerID)
        default:
            return []
        }
    }

    private mutating func applyOfferSourceActions(
        id: DataOfferID,
        actions: DragActionSet
    ) throws -> [DataTransferEffect] {
        guard var offer = offers[id] else {
            throw DataTransferError.unknownOffer
        }

        let didChange = try offer.setDragSourceActions(actions)
        offers[id] = offer

        guard didChange, case .dragAndDrop(let seatID) = offer.role,
            activeDragOffers[seatID] == id
        else {
            return []
        }

        return [.publishDragOfferChanged(seatID: seatID, offerID: id)]
    }

    private mutating func applyOfferSelectedAction(
        id: DataOfferID,
        action: DragAction
    ) throws -> [DataTransferEffect] {
        guard var offer = offers[id] else {
            throw DataTransferError.unknownOffer
        }

        let didChange = try offer.setDragSelectedAction(action)
        offers[id] = offer

        guard didChange, case .dragAndDrop(let seatID) = offer.role,
            activeDragOffers[seatID] == id
        else {
            return []
        }

        return [.publishDragOfferChanged(seatID: seatID, offerID: id)]
    }

    private mutating func applyDragAccepted(
        id: DataOfferID,
        mimeType: MIMEType?
    ) throws -> [DataTransferEffect] {
        guard var offer = offers[id] else {
            throw DataTransferError.unknownOffer
        }

        guard case .dragAndDrop = offer.role else {
            throw DataTransferError.unknownDragOfferIdentity(id.dragIdentity)
        }

        if let mimeType, !offer.mimeTypes.contains(mimeType) {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }

        guard let currentMetadata = offer.dragAndDrop else {
            throw DataTransferError.unknownDragOfferIdentity(id.dragIdentity)
        }
        let acceptState: DragAcceptState
        if currentMetadata.acceptState == .rejected {
            acceptState = .rejected
        } else if let mimeType {
            acceptState = .accepted(mimeType)
        } else {
            acceptState = .rejected
        }
        try offer.setDragAcceptState(acceptState)
        offers[id] = offer
        return []
    }

    private mutating func applyDragActionsRequested(
        id: DataOfferID,
        preferredAction: DragAction
    ) throws -> [DataTransferEffect] {
        guard var offer = offers[id] else {
            throw DataTransferError.unknownOffer
        }

        guard case .dragAndDrop = offer.role else {
            throw DataTransferError.unknownDragOfferIdentity(id.dragIdentity)
        }

        try offer.recordFinalPreferredAction(preferredAction)
        offers[id] = offer
        return []
    }

    private mutating func applyDragEntered(
        _ enter: DataTransferDragEnterTransition
    ) throws -> [DataTransferEffect] {
        _ = try boundSeat(enter.seatID)
        guard var offer = offers[enter.offerID] else {
            throw DataTransferError.unknownOffer
        }
        guard case .dragAndDrop(enter.seatID) = offer.role else {
            throw DataTransferError.unknownOffer
        }
        guard offer.snapshot != nil else {
            throw DataTransferError.emptyDataOffer
        }

        try offer.setDragEnterSerial(enter.serial)
        offers[enter.offerID] = offer

        var effects: [DataTransferEffect] = []
        if let previousOfferID = activeDragOffers[enter.seatID],
            previousOfferID != enter.offerID
        {
            appendDragOfferCleanup(previousOfferID, to: &effects)
        }
        activeDragOffers[enter.seatID] = enter.offerID
        effects.append(.publishDragEntered(enter))
        return effects
    }

    private func applyDragMotion(
        seatID: SeatID,
        time: WaylandTimestampMilliseconds,
        location: DragLocation
    ) throws -> [DataTransferEffect] {
        _ = try boundSeat(seatID)
        guard let offerID = activeDragOffers[seatID] else {
            return []
        }
        guard offers[offerID]?.dragAndDrop?.hasDropped != true else {
            return []
        }

        return [
            .publishDragMotion(
                seatID: seatID,
                offerID: offerID,
                time: time,
                location: location
            )
        ]
    }

    private mutating func applyDragLeft(_ seatID: SeatID) -> [DataTransferEffect] {
        guard let offerID = activeDragOffers[seatID] else {
            return []
        }
        guard offers[offerID]?.dragAndDrop?.hasDropped != true else {
            return []
        }

        activeDragOffers[seatID] = nil
        var effects: [DataTransferEffect] = [
            .publishDragLeft(seatID: seatID, offerID: offerID)
        ]
        appendDragOfferCleanup(offerID, to: &effects)
        return effects
    }

    private mutating func applyDragDropped(_ seatID: SeatID) throws -> [DataTransferEffect] {
        guard let offerID = activeDragOffers[seatID] else {
            return []
        }

        guard var offer = offers[offerID] else {
            return []
        }
        guard offer.dragAndDrop?.hasDropped != true else {
            return []
        }

        try offer.markDragDropped()
        offers[offerID] = offer
        return [.publishDragDropped(seatID: seatID, offerID: offerID)]
    }

    private mutating func applyDragFinished(_ offerID: DataOfferID) -> [DataTransferEffect] {
        guard case .dragAndDrop(let seatID) = offers[offerID]?.role,
            activeDragOffers[seatID] == offerID
        else {
            return []
        }

        activeDragOffers[seatID] = nil
        var effects: [DataTransferEffect] = []
        appendDragOfferCleanup(offerID, to: &effects)
        return effects
    }
}
