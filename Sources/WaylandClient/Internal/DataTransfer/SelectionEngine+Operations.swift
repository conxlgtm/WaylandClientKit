import WaylandRaw

extension SelectionEngine {
    func setSelectionSource(
        seatID: SeatID,
        payloads: DataTransferSourcePayloadSet,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let device = try requireDevice(for: seatID)
        let sourceID = allocateSourceID()
        let sourceBinding = try backend.createSource(id: sourceID) { [weak self] event in
            self?.handleSourceEvent(event, sourceID: sourceID)
        }
        let source: SelectionEngineSourceRecord
        do {
            sourceBinding.offer(payloads.mimeTypes)
            source = try SelectionEngineSourceRecord(
                id: sourceID,
                seatID: seatID,
                binding: sourceBinding,
                payloads: payloads
            )
        } catch {
            sourceBinding.destroy()
            throw error
        }

        let previousSelection = selectionState(for: seatID)
        sourcesByID[sourceID] = source
        selectionBySeat[seatID] = .ownedSource(sourceID)
        let cleanup = removeSelection(previousSelection, publishSourceCancellation: true)

        device.setSelection(source: sourceBinding, serial: serial)
        perform(cleanup)
        return source.snapshot
    }

    func clearSelectionSource(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let device = try requireDevice(for: seatID)
        let previousSelection = selectionState(for: seatID)
        selectionBySeat[seatID] = DataSelectionState.none
        let cleanup = removeSelection(previousSelection, publishSourceCancellation: true)

        device.setSelection(source: nil, serial: serial)
        perform(cleanup)
    }

    func clearSelectionSource(
        id sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard selectionState(for: seatID) == .ownedSource(sourceID) else {
            throw DataTransferError.sourceCancelled
        }

        try clearSelectionSource(seatID: seatID, serial: serial)
    }

    func allocateSourceID() -> DataSourceID {
        sourceIDs.next()
    }

    func appendSourceSendRequest(_ request: DataTransferSourceSendRequest) {
        pendingSourceSendRequests.append(request)
    }

    func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        let requests = pendingSourceSendRequests.drain()
        detachedSourceSendIDs.removeAll(keepingCapacity: true)
        return requests
    }

    func pendingSourceSendRequestsForInvariantChecks() -> [DataTransferSourceSendRequest] {
        pendingSourceSendRequests
    }

    func removeSourceSendRequests(
        for sourceID: DataSourceID
    ) -> [DataTransferSourceSendRequest] {
        let requests = pendingSourceSendRequests.removeAllReturning { request in
            request.source.sourceID == sourceID
        }
        detachedSourceSendIDs.remove(sourceID)
        return requests
    }

    func detachExternalSourcePreservingPendingSends(_ sourceID: DataSourceID) {
        if pendingSourceSendRequests.contains(where: { $0.source.sourceID == sourceID }) {
            detachedSourceSendIDs.insert(sourceID)
        }
    }

    func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        guard !isShutdown else { return }
        pendingCallbackFailures.append(
            DataTransferCallbackFailure(
                context: context,
                error: DataTransferError(callbackBackendError: error)
            )
        )
    }

    func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard let failure = pendingCallbackFailures.popFirst() else { return }
        throw failure
    }

    func takePendingOfferForDrag(
        handle: RawDataOfferHandle,
        seatID: SeatID
    ) throws -> SelectionEngineClaimedOffer {
        let engineHandle = SelectionEngineOfferHandle.clipboard(handle)
        guard let offerID = offerIDsByHandle[engineHandle],
            let offer = offersByID[offerID]
        else {
            throw DataTransferError.unknownOfferHandle(
                rawValue: handle.rawValue,
                seatID: seatID
            )
        }
        guard !offer.isSelected else {
            throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
        }
        guard offer.seatID == seatID else {
            throw DataTransferError.mismatchedOfferSeat(
                offer: .dragAndDrop(offerID.dragIdentity),
                expected: seatID,
                actual: offer.seatID
            )
        }
        guard !offer.mimeTypes.isEmpty else {
            throw DataTransferError.emptyDataOffer
        }

        offersByID[offerID] = nil
        offerIDsByHandle[engineHandle] = nil
        return SelectionEngineClaimedOffer(
            handle: engineHandle,
            id: offerID,
            seatID: seatID,
            mimeTypes: offer.mimeTypes,
            binding: offer.binding
        )
    }

    func restoreClaimedOffer(_ claimed: SelectionEngineClaimedOffer) {
        precondition(offersByID[claimed.id] == nil, "selection offer was restored twice")
        precondition(
            offerIDsByHandle[claimed.handle] == nil,
            "selection offer handle was restored twice"
        )
        offersByID[claimed.id] = SelectionEngineOfferRecord(
            handle: claimed.handle,
            id: claimed.id,
            seatID: claimed.seatID,
            binding: claimed.binding,
            mimeTypes: claimed.mimeTypes
        )
        offerIDsByHandle[claimed.handle] = claimed.id
    }
}
