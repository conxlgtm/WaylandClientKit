extension DataTransferManager {
    package func selectionOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let seat = state.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        guard let offerID = seat.selectionOfferID else {
            return nil
        }
        guard let offer = state.offerSnapshot(offerID) else {
            throw DataTransferError.unknownOffer
        }

        return offer
    }
}
