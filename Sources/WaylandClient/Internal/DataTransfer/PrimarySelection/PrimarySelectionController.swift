// swiftlint:disable file_length

import WaylandRaw

package final class PrimarySelectionController {
    package let backend: any PrimarySelectionControllerBackend
    private let eventQueue: DataTransferEventQueue
    private var deviceBindings: [SeatID: any PrimarySelectionDeviceBinding] = [:]
    private var offerIDsByHandle: [RawPrimarySelectionOfferHandle: DataOfferID] = [:]
    private var offersByID: [DataOfferID: RuntimePrimarySelectionOffer] = [:]
    private var selectionBySeat: [SeatID: PrimarySelectionSelectionState] = [:]
    private var sourcesByID: [DataSourceID: RuntimePrimarySelectionSource] = [:]
    var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    private var pendingCallbackFailures: [DataTransferCallbackFailure] = []
    private var nextOfferID: UInt64 = 1
    private var nextSourceID: UInt64 = 1

    package init(
        connection rawConnection: RawDisplayConnection,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue()
    ) {
        backend = LivePrimarySelectionControllerBackend(connection: rawConnection)
        eventQueue = dataTransferEventQueue
    }

    package init(
        backend controllerBackend: any PrimarySelectionControllerBackend,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue()
    ) {
        controllerBackend.preconditionIsOwnerThread()
        backend = controllerBackend
        eventQueue = dataTransferEventQueue
    }

    package func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let desiredSeats = Set(seatIDs)
        let currentSeats = Set(deviceBindings.keys)
        for seatID in Self.sortedSeatIDs(currentSeats.subtracting(desiredSeats)) {
            removeSeat(seatID)
        }
        for seatID in Self.sortedSeatIDs(desiredSeats.subtracting(currentSeats)) {
            try bindDevice(for: seatID)
        }
    }

    package func offer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard deviceBindings[seatID] != nil else {
            throw DataTransferError.missingPrimarySelectionDevice(seatID)
        }

        guard case .remoteOffer(let offerID) = selectionBySeat[seatID] ?? .none else {
            return nil
        }

        return offersByID[offerID]?.snapshot
    }

    package func receiveOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let offer = offersByID[offerID]?.snapshot else {
            throw DataTransferError.unknownPrimarySelectionOfferIdentity(
                offerID.primarySelectionIdentity
            )
        }
        guard offer.mimeTypes.contains(mimeType) else {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }
        guard let binding = offersByID[offerID]?.binding else {
            throw DataTransferError.offerExpired
        }

        let descriptors = try backend.makeOfferReceivePipe()
        var readEnd = try adoptReadEnd(descriptors)
        try receiveIntoPipe(
            binding,
            mimeType: mimeType,
            descriptors: descriptors,
            readEnd: &readEnd
        )
        return readEnd
    }

    package func setSelectionSource(
        seatID: SeatID,
        payloads: DataTransferSourcePayloadSet,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let deviceBinding = try primarySelectionDeviceBinding(for: seatID)
        let sourceID = allocateSourceID()
        let sourceBinding = try backend.createPrimarySelectionSource(
            id: sourceID,
            onEvent: sourceEventHandler(for: sourceID)
        )
        do {
            for mimeType in payloads.mimeTypes {
                sourceBinding.offer(mimeType: mimeType)
            }
            let source = try RuntimePrimarySelectionSource(
                id: sourceID,
                seatID: seatID,
                binding: sourceBinding,
                payloads: payloads
            )
            sourcesByID[sourceID] = source
            cleanupSelection(selectionBySeat[seatID] ?? .none)
            selectionBySeat[seatID] = .ownedSource(sourceID)
            deviceBinding.setSelection(source: sourceBinding, serial: serial)
        } catch {
            sourceBinding.destroy()
            sourcesByID[sourceID] = nil
            throw error
        }

        guard let source = sourcesByID[sourceID]?.snapshot else {
            throw DataTransferError.unknownPrimarySelectionSourceIdentity(
                sourceID.primarySelectionIdentity
            )
        }

        return source
    }

    package func clearSelectionSource(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let deviceBinding = try primarySelectionDeviceBinding(for: seatID)
        deviceBinding.setSelection(source: nil, serial: serial)
        let currentSelection = selectionBySeat[seatID] ?? .none
        cleanupSelection(currentSelection)
        selectionBySeat[seatID] = PrimarySelectionSelectionState.none
    }

    package func clearSelectionSource(
        id sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard (selectionBySeat[seatID] ?? .none) == .ownedSource(sourceID) else {
            throw DataTransferError.sourceCancelled
        }

        try clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    func shutdown() {
        backend.preconditionIsOwnerThread()
        for sourceID in sourcesByID.keys.sortedByRawValue() {
            sourcesByID.removeValue(forKey: sourceID)?.binding.destroy()
        }
        for offerID in offersByID.keys.sortedByRawValue() {
            destroyOffer(offerID)
        }
        for seatID in deviceBindings.keys.sortedByRawValue() {
            deviceBindings.removeValue(forKey: seatID)?.release()
        }
        discardAllPendingSourceSendRequests()
        selectionBySeat.removeAll(keepingCapacity: false)
        offerIDsByHandle.removeAll(keepingCapacity: false)
        pendingCallbackFailures.removeAll(keepingCapacity: false)
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard !pendingCallbackFailures.isEmpty else { return }

        throw pendingCallbackFailures.removeFirst()
    }
}

extension PrimarySelectionController {
    private func bindDevice(for seatID: SeatID) throws {
        guard deviceBindings[seatID] == nil else {
            return
        }

        let binding = try backend.bindPrimarySelectionDevice(for: seatID) { [weak self] event in
            self?.handleDeviceEvent(event, seatID: seatID)
        }
        deviceBindings[seatID] = binding
        selectionBySeat[seatID] = PrimarySelectionSelectionState.none
    }

    private func removeSeat(_ seatID: SeatID) {
        var pendingOfferIDsForSeat: [DataOfferID] = []
        for (offerID, offer) in offersByID where offer.pendingSeatID == seatID {
            pendingOfferIDsForSeat.append(offerID)
        }
        pendingOfferIDsForSeat.sortByRawValue()

        var sourceIDsForSeat: [DataSourceID] = []
        for (sourceID, source) in sourcesByID where source.snapshot.seatID == seatID {
            sourceIDsForSeat.append(sourceID)
        }
        sourceIDsForSeat.sortByRawValue()

        deviceBindings.removeValue(forKey: seatID)?.release()
        cleanupSelection(selectionBySeat.removeValue(forKey: seatID) ?? .none)

        for offerID in pendingOfferIDsForSeat {
            destroyOffer(offerID)
        }
        for sourceID in sourceIDsForSeat {
            _ = cancelSource(sourceID)
        }
    }

    private func handleDeviceEvent(_ event: RawPrimarySelectionDeviceEvent, seatID: SeatID) {
        do {
            switch event {
            case .dataOffer(let handle):
                try handleDataOffer(handle, seatID: seatID)
            case .selection(nil):
                let currentSelection = selectionBySeat[seatID] ?? .none
                guard currentSelection != .none else {
                    return
                }

                cleanupSelection(currentSelection)
                selectionBySeat[seatID] = PrimarySelectionSelectionState.none
                publishSelectionChanged(seatID: seatID, offerID: nil)
            case .selection(.some(let handle)):
                try handleSelection(handle: handle, seatID: seatID)
            }
        } catch {
            recordCallbackError(error, context: .primarySelectionDevice(seatID))
        }
    }

    private func handleDataOffer(
        _ handle: RawPrimarySelectionOfferHandle?,
        seatID: SeatID
    ) throws {
        guard let handle else {
            throw DataTransferError.missingOfferHandle(seatID: seatID)
        }
        guard offerIDsByHandle[handle] == nil else {
            throw DataTransferError.duplicatePrimarySelectionOfferHandle(
                rawValue: handle.rawValue,
                existingOffer: offerIDsByHandle[handle].map(PrimarySelectionOfferIdentity.init)
            )
        }

        let offerID = allocateOfferID()
        let binding = try backend.adoptPrimarySelectionOffer(
            handle: handle,
            id: offerID
        ) { [weak self] event in
            self?.handleOfferEvent(event, offerID: offerID)
        }
        offerIDsByHandle[handle] = offerID
        offersByID[offerID] = .pending(
            handle: handle,
            binding: binding,
            seatID: seatID,
            mimeTypes: []
        )
    }

    private func handleOfferEvent(
        _ event: RawPrimarySelectionOfferEvent,
        offerID: DataOfferID
    ) {
        do {
            guard case .offer(let rawMimeType) = event else {
                return
            }

            guard let rawMimeType, let mimeType = MIMEType(rawValue: rawMimeType) else { return }
            guard var offer = offersByID[offerID] else {
                throw DataTransferError.unknownPrimarySelectionOfferIdentity(
                    offerID.primarySelectionIdentity
                )
            }
            let changed = try offer.appendMIMETypeIfNew(mimeType)
            offersByID[offerID] = offer
            if changed, let snapshot = offer.snapshot {
                publishSelectionChanged(seatID: snapshot.role.seatID, offerID: offerID)
            }
        } catch {
            recordCallbackError(
                error,
                context: .primarySelectionOffer(offerID.primarySelectionIdentity)
            )
        }
    }

    private func handleSelection(
        handle: RawPrimarySelectionOfferHandle,
        seatID: SeatID
    ) throws {
        guard let offerID = offerIDsByHandle[handle] else {
            throw DataTransferError.unknownOfferHandle(
                rawValue: handle.rawValue,
                seatID: seatID
            )
        }
        guard var offer = offersByID[offerID] else {
            throw DataTransferError.unknownPrimarySelectionOfferIdentity(
                offerID.primarySelectionIdentity
            )
        }
        if let snapshot = offer.snapshot {
            guard snapshot.role.seatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: .primarySelection(offerID.primarySelectionIdentity),
                    expected: seatID,
                    actual: snapshot.role.seatID
                )
            }
        } else {
            guard offer.pendingSeatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: .primarySelection(offerID.primarySelectionIdentity),
                    expected: seatID,
                    actual: offer.pendingSeatID
                )
            }
            guard !offer.pendingMIMETypes.isEmpty else {
                throw DataTransferError.emptyDataOffer
            }
            try offer.markActive(id: offerID)
            offersByID[offerID] = offer
        }

        guard selectionBySeat[seatID] != .remoteOffer(offerID) else {
            return
        }

        cleanupSelection(selectionBySeat[seatID] ?? .none)
        selectionBySeat[seatID] = .remoteOffer(offerID)
        publishSelectionChanged(seatID: seatID, offerID: offerID)
    }

    private func handleSourceEvent(
        _ event: RawPrimarySelectionSourceEvent,
        sourceID: DataSourceID
    ) {
        do {
            switch event {
            case .send(let rawMimeType, let descriptor):
                try handleSourceSend(
                    mimeType: rawMimeType,
                    descriptor: descriptor,
                    sourceID: sourceID
                )
            case .cancelled:
                if cancelSource(sourceID) {
                    eventQueue.append(
                        .primarySelectionSourceCancelled(sourceID.primarySelectionIdentity)
                    )
                }
            }
        } catch {
            recordCallbackError(
                error,
                context: .primarySelectionSource(sourceID.primarySelectionIdentity)
            )
        }
    }

    private func sourceEventHandler(
        for sourceID: DataSourceID
    ) -> (RawPrimarySelectionSourceEvent) -> Void {
        { [weak self] event in
            self?.handleSourceEvent(event, sourceID: sourceID)
        }
    }

    private func handleSourceSend(
        mimeType rawMimeType: String?,
        descriptor: Int32,
        sourceID: DataSourceID
    ) throws {
        do {
            guard let source = sourcesByID[sourceID] else {
                throw DataTransferError.unknownPrimarySelectionSourceIdentity(
                    sourceID.primarySelectionIdentity
                )
            }
            let mimeType = try MIMEType(rawMimeType ?? "")
            guard source.snapshot.mimeTypes.contains(mimeType) else {
                throw DataTransferError.mimeTypeUnavailable(mimeType)
            }
            guard let data = source.payloads.data(for: mimeType) else {
                throw DataTransferError.sourceDataUnavailable(mimeType)
            }

            pendingSourceSendRequests.append(
                try DataTransferSourceSendRequest(
                    source: .primarySelection(sourceID),
                    mimeType: mimeType,
                    descriptor: descriptor,
                    data: data,
                    descriptorIO: backend.sourceDescriptorIO
                )
            )
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }
    }

    private func primarySelectionDeviceBinding(
        for seatID: SeatID
    ) throws -> any PrimarySelectionDeviceBinding {
        guard let deviceBinding = deviceBindings[seatID] else {
            throw DataTransferError.missingPrimarySelectionDevice(seatID)
        }

        return deviceBinding
    }

    private func cleanupSelection(_ selection: PrimarySelectionSelectionState) {
        switch selection {
        case .none:
            return
        case .remoteOffer(let offerID):
            destroyOffer(offerID)
        case .ownedSource(let sourceID):
            if cancelSource(sourceID) {
                eventQueue.append(
                    .primarySelectionSourceCancelled(sourceID.primarySelectionIdentity)
                )
            }
        }
    }

    private func destroyOffer(_ offerID: DataOfferID) {
        guard let offer = offersByID.removeValue(forKey: offerID) else {
            return
        }

        offerIDsByHandle[offer.handle] = nil
        offer.binding.destroy()
    }

    private func cancelSource(_ sourceID: DataSourceID) -> Bool {
        guard let source = sourcesByID.removeValue(forKey: sourceID) else {
            discardPendingSourceSendRequests(for: sourceID)
            return false
        }

        source.binding.destroy()
        discardPendingSourceSendRequests(for: sourceID)
        var selectedSeatIDs: [SeatID] = []
        for (seatID, selection) in selectionBySeat where selection == .ownedSource(sourceID) {
            selectedSeatIDs.append(seatID)
        }

        for seatID in selectedSeatIDs {
            selectionBySeat[seatID] = PrimarySelectionSelectionState.none
        }
        return true
    }

    func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        pendingCallbackFailures.append(
            DataTransferCallbackFailure(
                context: context,
                error: DataTransferError(callbackBackendError: error)
            )
        )
    }

    private func publishSelectionChanged(seatID: SeatID, offerID: DataOfferID?) {
        eventQueue.append(.primarySelectionChanged(.init(seatID: seatID, offerID: offerID)))
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sortedByRawValue()
    }

    private func allocateOfferID() -> DataOfferID {
        defer { nextOfferID += 1 }
        return DataOfferID(rawValue: nextOfferID)
    }

    private func allocateSourceID() -> DataSourceID {
        defer { nextSourceID += 1 }
        return DataSourceID(rawValue: nextSourceID)
    }
}
