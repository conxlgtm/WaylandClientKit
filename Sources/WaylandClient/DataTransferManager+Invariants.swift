package enum DataTransferManagerInvariantViolation:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case dataDeviceBindingsDoNotMatchSeats
    case offerHandleIndexDoesNotMatchRecords
    case runtimeOfferBindingIDMismatch(expected: DataOfferID, actual: DataOfferID)
    case activeOfferMissingRuntimeBinding(DataOfferID)
    case activeRuntimeOfferMissingState(DataOfferID)
    case pendingRuntimeOfferHasState(DataOfferID)
    case pendingRuntimeOfferMissingSeat(DataOfferID, SeatID)
    case sourceBindingsDoNotMatchState
    case sourceProviderWithoutSource(DataSourceID)
    case pendingSourceSendRequestMissingSource(DataSourceID)
    case seatSelectionReferencesMissingOffer(SeatID, DataOfferID)
    case seatSelectionReferencesMissingSource(SeatID, DataSourceID)

    package var description: String {
        switch self {
        case .dataDeviceBindingsDoNotMatchSeats:
            "data device bindings do not match bound seats"
        case .offerHandleIndexDoesNotMatchRecords:
            "offer handle index does not match runtime offer records"
        case .runtimeOfferBindingIDMismatch(let expected, let actual):
            "runtime offer \(expected) has binding \(actual)"
        case .activeOfferMissingRuntimeBinding(let offerID):
            "active offer \(offerID) has no runtime binding"
        case .activeRuntimeOfferMissingState(let offerID):
            "runtime offer \(offerID) is active but absent from state"
        case .pendingRuntimeOfferHasState(let offerID):
            "runtime offer \(offerID) is pending but already present in state"
        case .pendingRuntimeOfferMissingSeat(let offerID, let seatID):
            "pending offer \(offerID) references missing seat \(seatID)"
        case .sourceBindingsDoNotMatchState:
            "source bindings do not match active sources"
        case .sourceProviderWithoutSource(let sourceID):
            "source provider \(sourceID) has no active source"
        case .pendingSourceSendRequestMissingSource(let sourceID):
            "source send request references missing source \(sourceID)"
        case .seatSelectionReferencesMissingOffer(let seatID, let offerID):
            "seat \(seatID) selection references missing offer \(offerID)"
        case .seatSelectionReferencesMissingSource(let seatID, let sourceID):
            "seat \(seatID) selection references missing source \(sourceID)"
        }
    }
}

extension DataTransferManager {
    package func checkInvariantsForTesting() throws {
        backend.preconditionIsOwnerThread()

        let seatsWithDataDevice = Set(
            state.seatSnapshots
                .filter(\.hasDataDevice)
                .map(\.seatID)
        )
        try checkSeatBindingInvariants(seatsWithDataDevice: seatsWithDataDevice)
        try checkOfferRuntimeInvariants(seatsWithDataDevice: seatsWithDataDevice)
        try checkSourceRuntimeInvariants()
        try checkSelectionReferenceInvariants()
    }

    private func checkSeatBindingInvariants(
        seatsWithDataDevice: Set<SeatID>
    ) throws {
        guard Set(deviceBindings.keys) == seatsWithDataDevice else {
            throw DataTransferManagerInvariantViolation.dataDeviceBindingsDoNotMatchSeats
        }
    }

    private func checkOfferRuntimeInvariants(
        seatsWithDataDevice: Set<SeatID>
    ) throws {
        let runtimeOfferIDs = Set(runtimeOffersByID.keys)
        let indexedOfferIDs = Set(offerIDsByHandle.values)
        guard runtimeOfferIDs == indexedOfferIDs else {
            throw DataTransferManagerInvariantViolation.offerHandleIndexDoesNotMatchRecords
        }
        for (handle, offerID) in offerIDsByHandle {
            guard runtimeOffersByID[offerID]?.handle == handle else {
                throw DataTransferManagerInvariantViolation.offerHandleIndexDoesNotMatchRecords
            }
        }

        let activeOffersByID = Dictionary(
            uniqueKeysWithValues: state.offerSnapshots.map { ($0.id, $0) }
        )
        let activeOfferIDs = Set(activeOffersByID.keys)
        for offerID in activeOfferIDs where runtimeOffersByID[offerID] == nil {
            throw DataTransferManagerInvariantViolation.activeOfferMissingRuntimeBinding(offerID)
        }
        for (offerID, runtimeOffer) in runtimeOffersByID {
            try checkRuntimeOffer(
                offerID,
                runtimeOffer,
                activeOffersByID: activeOffersByID,
                seatsWithDataDevice: seatsWithDataDevice
            )
        }
    }

    private func checkRuntimeOffer(
        _ offerID: DataOfferID,
        _ runtimeOffer: RuntimeDataOffer,
        activeOffersByID: [DataOfferID: DataOfferSnapshot],
        seatsWithDataDevice: Set<SeatID>
    ) throws {
        guard runtimeOffer.binding.id == offerID else {
            throw DataTransferManagerInvariantViolation.runtimeOfferBindingIDMismatch(
                expected: offerID,
                actual: runtimeOffer.binding.id
            )
        }

        switch runtimeOffer {
        case .active:
            guard activeOffersByID[offerID] != nil else {
                throw
                    DataTransferManagerInvariantViolation
                    .activeRuntimeOfferMissingState(offerID)
            }
        case .pending(_, _, let seatID, _):
            guard activeOffersByID[offerID] == nil else {
                throw DataTransferManagerInvariantViolation.pendingRuntimeOfferHasState(offerID)
            }
            guard seatsWithDataDevice.contains(seatID) else {
                throw
                    DataTransferManagerInvariantViolation
                    .pendingRuntimeOfferMissingSeat(offerID, seatID)
            }
        }
    }

    private func checkSourceRuntimeInvariants() throws {
        let activeSourceIDs = Set(state.sourceSnapshots.map(\.id))
        guard Set(sourceBindingsByID.keys) == activeSourceIDs else {
            throw DataTransferManagerInvariantViolation.sourceBindingsDoNotMatchState
        }
        for sourceID in sourceProvidersByID.keys where !activeSourceIDs.contains(sourceID) {
            throw DataTransferManagerInvariantViolation.sourceProviderWithoutSource(sourceID)
        }
        for request in pendingSourceSendRequests where !activeSourceIDs.contains(request.sourceID) {
            throw
                DataTransferManagerInvariantViolation
                .pendingSourceSendRequestMissingSource(request.sourceID)
        }
    }

    private func checkSelectionReferenceInvariants() throws {
        let activeOfferIDs = Set(state.offerSnapshots.map(\.id))
        let activeSourceIDs = Set(state.sourceSnapshots.map(\.id))

        for seat in state.seatSnapshots {
            if let offerID = seat.selectionOfferID, !activeOfferIDs.contains(offerID) {
                throw
                    DataTransferManagerInvariantViolation
                    .seatSelectionReferencesMissingOffer(seat.seatID, offerID)
            }
            if let sourceID = seat.selectionSourceID, !activeSourceIDs.contains(sourceID) {
                throw
                    DataTransferManagerInvariantViolation
                    .seatSelectionReferencesMissingSource(seat.seatID, sourceID)
            }
        }
    }
}
