extension SelectionEngine {
    func handleDeviceEvent(
        _ event: SelectionEngineDeviceEvent,
        seatID: SeatID
    ) {
        guard !isShutdown else { return }
        defer { preconditionInvariantsHold() }
        do {
            switch event {
            case .dataOffer(let handle):
                try handleDataOffer(handle, seatID: seatID)
            case .selection(let handle):
                guard deviceBindings[seatID] != nil else {
                    throw DataTransferError.unknownSeat(seatID)
                }
                try handleSelection(handle: handle, seatID: seatID)
            }
        } catch {
            recordCallbackError(error, context: kind.deviceCallbackContext(seatID))
        }
    }

    func handleDataOffer(
        _ handle: SelectionEngineOfferHandle?,
        seatID: SeatID
    ) throws {
        guard let handle else {
            throw DataTransferError.missingOfferHandle(seatID: seatID)
        }
        guard deviceBindings[seatID] != nil else {
            throw DataTransferError.unknownSeat(seatID)
        }
        let existingOfferID = offerIDsByHandle[handle] ?? hooks.externalOfferID(handle)
        guard existingOfferID == nil else {
            throw kind.duplicateOfferError(
                handle: handle,
                existingOfferID: existingOfferID
            )
        }

        let offerID = allocateOfferID()
        let binding = try backend.adoptOffer(handle: handle, id: offerID) { [weak self] event in
            self?.handleOfferEvent(event, offerID: offerID)
        }
        offersByID[offerID] = SelectionEngineOfferRecord(
            handle: handle,
            id: offerID,
            seatID: seatID,
            binding: binding
        )
        offerIDsByHandle[handle] = offerID
    }

    func handleSelection(
        handle: SelectionEngineOfferHandle?,
        seatID: SeatID
    ) throws {
        _ = try requireDevice(for: seatID)
        guard let handle else {
            let current = selectionState(for: seatID)
            guard current != .none else { return }

            selectionBySeat[seatID] = DataSelectionState.none
            let cleanup = removeSelection(current, publishSourceCancellation: true)
            perform(cleanup)
            eventQueue.append(kind.selectionChangedEvent(seatID: seatID, offerID: nil))
            return
        }
        guard let offerID = offerIDsByHandle[handle], var offer = offersByID[offerID] else {
            throw DataTransferError.unknownOfferHandle(
                rawValue: handle.rawValue,
                seatID: seatID
            )
        }
        guard offer.seatID == seatID else {
            throw DataTransferError.mismatchedOfferSeat(
                offer: kind.offerIdentity(offerID),
                expected: seatID,
                actual: offer.seatID
            )
        }
        guard !offer.mimeTypes.isEmpty else {
            throw DataTransferError.emptyDataOffer
        }
        guard selectionState(for: seatID) != .remoteOffer(offerID) else { return }

        offer.isSelected = true
        offersByID[offerID] = offer
        let current = selectionState(for: seatID)
        selectionBySeat[seatID] = .remoteOffer(offerID)
        let cleanup = removeSelection(current, publishSourceCancellation: true)

        perform(cleanup)
        eventQueue.append(kind.selectionChangedEvent(seatID: seatID, offerID: offerID))
    }

    func handleOfferEvent(
        _ event: SelectionEngineOfferEvent,
        offerID: DataOfferID
    ) {
        guard !isShutdown else { return }
        defer { preconditionInvariantsHold() }
        guard var offer = offersByID[offerID] else {
            if hooks.unownedOfferEvent(event, offerID) {
                return
            }
            recordCallbackError(
                kind.unknownOfferError(offerID),
                context: kind.offerCallbackContext(offerID)
            )
            return
        }

        switch event {
        case .mimeType(let rawMIMEType):
            guard let rawMIMEType, let mimeType = MIMEType(rawValue: rawMIMEType) else {
                return
            }
            let didChange = offer.appendMIMETypeIfNew(mimeType)
            offersByID[offerID] = offer
            if didChange, offer.isSelected {
                eventQueue.append(
                    kind.selectionChangedEvent(seatID: offer.seatID, offerID: offerID)
                )
            }
        }
    }

    func handleSourceEvent(
        _ event: SelectionEngineSourceEvent,
        sourceID: DataSourceID
    ) {
        if isShutdown {
            if case .send(_, let descriptor) = event {
                _ = backend.closeFileDescriptor(descriptor)
            }
            return
        }
        defer { preconditionInvariantsHold() }

        do {
            switch event {
            case .send(let rawMIMEType, let descriptor):
                try handleSourceSend(
                    mimeType: rawMIMEType,
                    descriptor: descriptor,
                    sourceID: sourceID
                )
            case .cancelled:
                cancelSourceFromCallback(sourceID)
            case .target:
                return
            case .invalidDragAndDropEvent(let eventKind):
                guard sourcesByID[sourceID] != nil else {
                    throw kind.unknownSourceError(sourceID)
                }
                throw DataTransferError.invalidSourceEvent(eventKind)
            }
        } catch {
            recordCallbackError(error, context: kind.sourceCallbackContext(sourceID))
        }
    }

    func handleSourceSend(
        mimeType rawMIMEType: String?,
        descriptor: Int32,
        sourceID: DataSourceID
    ) throws {
        let context: (SelectionEngineSourceRecord, MIMEType)?
        do {
            context = try sourceSendContext(
                rawMIMEType: rawMIMEType,
                sourceID: sourceID
            )
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }

        guard let (source, mimeType) = context else {
            try closeSourceSendDescriptor(descriptor)
            return
        }

        do {
            let prepared = try PreparedDataTransferSourceSend(
                source: kind.writeSource(sourceID),
                snapshot: source.snapshot,
                data: source.payloads.data(for: mimeType),
                mimeType: mimeType,
                descriptor: descriptor,
                descriptorIO: backend.sourceDescriptorIO
            )
            pendingSourceSendRequests.append(prepared.request)
            eventQueue.append(prepared.event)
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }
    }

    func sourceSendContext(
        rawMIMEType: String?,
        sourceID: DataSourceID
    ) throws -> (SelectionEngineSourceRecord, MIMEType)? {
        switch kind {
        case .clipboard:
            guard let mimeType = try kind.sourceSendMIMEType(rawMIMEType) else {
                return nil
            }
            guard let source = sourcesByID[sourceID] else {
                throw kind.unknownSourceError(sourceID)
            }
            return (source, mimeType)
        case .primarySelection:
            guard let source = sourcesByID[sourceID] else {
                throw kind.unknownSourceError(sourceID)
            }
            guard let mimeType = try kind.sourceSendMIMEType(rawMIMEType) else {
                preconditionFailure("primary-selection MIME parsing returned no value")
            }
            return (source, mimeType)
        }
    }

    func cancelSourceFromCallback(_ sourceID: DataSourceID) {
        guard let source = sourcesByID.removeValue(forKey: sourceID) else { return }

        for seatID in selectionBySeat.keys
        where selectionBySeat[seatID] == .ownedSource(sourceID) {
            selectionBySeat[seatID] = DataSelectionState.none
        }
        let requests = removeSourceSendRequests(for: sourceID)

        hooks.sourceWillCancel(sourceID)
        source.binding.destroy()
        discardSourceSendRequests(requests)
        eventQueue.append(kind.sourceCancelledEvent(sourceID))
    }
}
