extension SelectionEngine {
    func checkInvariantsForTesting(
        externalSourceIDs: Set<DataSourceID> = []
    ) throws {
        let seatIDs = Set(deviceBindings.keys)
        guard seatIDs == Set(selectionBySeat.keys) else {
            throw DataTransferManagerInvariantViolation.dataDeviceBindingsDoNotMatchSeats
        }

        try checkOfferInvariants(seatIDs: seatIDs)
        try checkSourceInvariants(
            seatIDs: seatIDs,
            externalSourceIDs: externalSourceIDs
        )
        try checkSelectionInvariants()
    }

    private func checkOfferInvariants(seatIDs: Set<SeatID>) throws {
        guard Set(offersByID.keys) == Set(offerIDsByHandle.values) else {
            throw DataTransferManagerInvariantViolation.offerHandleIndexDoesNotMatchRecords
        }
        for (handle, offerID) in offerIDsByHandle
        where offersByID[offerID]?.handle != handle {
            throw DataTransferManagerInvariantViolation.offerHandleIndexDoesNotMatchRecords
        }
        for offer in offersByID.values where !seatIDs.contains(offer.seatID) {
            throw DataTransferManagerInvariantViolation.pendingRuntimeOfferMissingSeat(
                offer.id,
                offer.seatID
            )
        }
    }

    private func checkSourceInvariants(
        seatIDs: Set<SeatID>,
        externalSourceIDs: Set<DataSourceID>
    ) throws {
        for (sourceID, source) in sourcesByID {
            guard source.snapshot.id == sourceID, source.binding.id == sourceID else {
                throw DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                    expected: sourceID,
                    actual: source.binding.id
                )
            }
            guard seatIDs.contains(source.snapshot.seatID) else {
                throw DataTransferManagerInvariantViolation.sourceBindingsDoNotMatchState
            }
        }

        let activeSourceIDs = Set(sourcesByID.keys)
            .union(externalSourceIDs)
            .union(detachedSourceSendIDs)
        for request in pendingSourceSendRequests
        where !activeSourceIDs.contains(request.source.sourceID) {
            throw DataTransferManagerInvariantViolation.pendingSourceSendRequestMissingSource(
                request.source.sourceID
            )
        }
    }

    private func checkSelectionInvariants() throws {
        for (seatID, selection) in selectionBySeat {
            if let offerID = selection.offerID {
                guard let offer = offersByID[offerID], offer.isSelected else {
                    throw
                        DataTransferManagerInvariantViolation
                        .seatSelectionReferencesMissingOffer(seatID, offerID)
                }
                guard !offer.mimeTypes.isEmpty else {
                    throw
                        DataTransferManagerInvariantViolation
                        .seatSelectionReferencesEmptyOffer(seatID, offerID)
                }
                guard offer.seatID == seatID else {
                    throw
                        DataTransferManagerInvariantViolation
                        .seatSelectionReferencesMissingOffer(seatID, offerID)
                }
            }
            if let sourceID = selection.sourceID,
                sourcesByID[sourceID]?.snapshot.seatID != seatID
            {
                throw
                    DataTransferManagerInvariantViolation
                    .seatSelectionReferencesMissingSource(seatID, sourceID)
            }
        }
    }

    func shutdown() {
        let committed = commitShutdown()
        for source in committed.sources {
            source.destroy()
        }
        for offer in committed.offers {
            offer.binding.destroy()
        }
        for device in committed.devices {
            device.release()
        }
        DataTransferSourceSendLifecycle.discardRequests(
            committed.pendingSourceSendRequests
        ) { _, _ in
            // Teardown cannot surface descriptor-close failures through a closed display.
        }
    }

    func commitShutdown() -> CommittedSelectionEngineShutdown {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else {
            return CommittedSelectionEngineShutdown(
                sources: [],
                offers: [],
                devices: [],
                pendingSourceSendRequests: []
            )
        }
        isShutdown = true

        let devices = deviceBindings.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value)
        let offers = offersByID.values.sortedByRawValue(\.id)
        let sources = sourcesByID.values.sortedByRawValue(\.snapshot.id)
        let requests = pendingSourceSendRequests

        deviceBindings.removeAll(keepingCapacity: false)
        offerIDsByHandle.removeAll(keepingCapacity: false)
        offersByID.removeAll(keepingCapacity: false)
        selectionBySeat.removeAll(keepingCapacity: false)
        sourcesByID.removeAll(keepingCapacity: false)
        pendingSourceSendRequests.removeAll(keepingCapacity: false)
        detachedSourceSendIDs.removeAll(keepingCapacity: false)
        pendingCallbackFailures.removeAll(keepingCapacity: false)

        for offer in offers {
            hooks.offerDidDestroy(offer.id)
        }
        return CommittedSelectionEngineShutdown(
            sources: sources.map(\.binding),
            offers: offers.map { offer in
                CommittedSelectionEngineOffer(id: offer.id, binding: offer.binding)
            },
            devices: devices,
            pendingSourceSendRequests: requests
        )
    }

    func requireDevice(
        for seatID: SeatID
    ) throws -> any SelectionEngineDeviceBinding {
        guard let device = deviceBindings[seatID] else {
            throw kind.missingDeviceError(seatID)
        }
        return device
    }

    func removeSelection(
        _ selection: DataSelectionState,
        publishSourceCancellation: Bool
    ) -> SelectionEngineCleanup {
        var cleanup = SelectionEngineCleanup()
        if let offerID = selection.offerID, let offer = removeOffer(offerID) {
            cleanup.offers.append(offer)
        }
        if let sourceID = selection.sourceID {
            appendRemovedSource(
                sourceID,
                publishCancellation: publishSourceCancellation,
                to: &cleanup
            )
        }
        return cleanup
    }

    func removeOffer(_ offerID: DataOfferID) -> SelectionEngineOfferRecord? {
        guard let offer = offersByID.removeValue(forKey: offerID) else { return nil }

        offerIDsByHandle[offer.handle] = nil
        return offer
    }

    func appendRemovedSource(
        _ sourceID: DataSourceID,
        publishCancellation: Bool,
        to cleanup: inout SelectionEngineCleanup
    ) {
        guard let source = sourcesByID.removeValue(forKey: sourceID) else { return }

        cleanup.sources.append(
            SelectionEngineCleanupSource(
                id: sourceID,
                record: source,
                publishesCancellation: publishCancellation
            )
        )
        cleanup.requests.append(contentsOf: removeSourceSendRequests(for: sourceID))
    }

    func perform(_ cleanup: SelectionEngineCleanup) {
        for offer in cleanup.offers {
            hooks.offerDidDestroy(offer.id)
            offer.binding.destroy()
        }
        for source in cleanup.sources {
            hooks.sourceWillCancel(source.id)
            source.record.binding.destroy()
            if source.publishesCancellation {
                eventQueue.append(kind.sourceCancelledEvent(source.id))
            }
        }
        discardSourceSendRequests(cleanup.requests)
    }

    func discardSourceSendRequests(
        _ requests: [DataTransferSourceSendRequest]
    ) {
        DataTransferSourceSendLifecycle.discardRequests(requests) { request, error in
            self.recordCallbackError(
                error,
                context: self.kind.discardedSendContext(request)
            )
        }
    }

    func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        try DataTransferSourceSendLifecycle.closeCallbackDescriptor(
            descriptor,
            close: backend.closeFileDescriptor
        )
    }

    func allocateOfferID() -> DataOfferID {
        offerIDs.next()
    }

    func preconditionInvariantsHold() {
        #if DEBUG
            do {
                try checkInvariantsForTesting(externalSourceIDs: hooks.externalSourceIDs())
            } catch {
                preconditionFailure("SelectionEngine invariant violation: \(error)")
            }
        #endif
    }
}
