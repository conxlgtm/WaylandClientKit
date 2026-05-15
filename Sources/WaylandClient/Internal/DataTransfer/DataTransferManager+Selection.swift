extension DataTransferManager {
    package func selectionOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let seat = store.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        guard let offerID = seat.selectionOfferID else {
            return nil
        }
        guard let offer = store.offerSnapshot(offerID) else {
            throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
        }

        return offer
    }

    package func dragOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let seat = store.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        guard let offerID = seat.dragAndDropOfferID else {
            return nil
        }

        return try dragOffer(id: offerID)
    }

    package func dragOffer(id offerID: DataOfferID) throws -> DataOfferSnapshot {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let offer = store.offerSnapshot(offerID),
            case .dragAndDrop(let seatID) = offer.role
        else {
            throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
        }
        guard store.seatSnapshot(seatID)?.dragAndDropOfferID == offerID else {
            throw DataTransferError.dragOfferNotActive(offerID.dragIdentity)
        }
        guard offer.dragAndDrop?.enterSerial != nil else {
            throw DataTransferError.dragOfferNotActive(offerID.dragIdentity)
        }

        return offer
    }
}
