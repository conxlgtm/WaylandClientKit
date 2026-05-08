import WaylandRaw

package protocol PrimarySelectionDeviceBinding: AnyObject {
    var seatID: SeatID { get }

    func setSelection(source: (any PrimarySelectionSourceBinding)?, serial: InputSerial)
    func release()
}

package protocol PrimarySelectionOfferBinding: AnyObject {
    var id: DataOfferID { get }

    func receive(mimeType: MIMEType, fd: Int32)
    func destroy()
}

package protocol PrimarySelectionSourceBinding: AnyObject {
    var id: DataSourceID { get }

    func offer(mimeType: MIMEType)
    func destroy()
}

package protocol PrimarySelectionControllerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func bindPrimarySelectionDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) throws -> any PrimarySelectionDeviceBinding
    func adoptPrimarySelectionOffer(
        handle: RawPrimarySelectionOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) throws -> any PrimarySelectionOfferBinding
    func createPrimarySelectionSource(
        id: DataSourceID,
        onEvent: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) throws -> any PrimarySelectionSourceBinding
    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

private enum RuntimePrimarySelectionOffer {
    case pending(
        handle: RawPrimarySelectionOfferHandle,
        binding: any PrimarySelectionOfferBinding,
        seatID: SeatID,
        mimeTypes: [MIMEType]
    )
    case active(
        handle: RawPrimarySelectionOfferHandle,
        binding: any PrimarySelectionOfferBinding,
        snapshot: DataOfferSnapshot
    )

    var handle: RawPrimarySelectionOfferHandle {
        switch self {
        case .pending(let handle, _, _, _), .active(let handle, _, _):
            handle
        }
    }

    var binding: any PrimarySelectionOfferBinding {
        switch self {
        case .pending(_, let binding, _, _), .active(_, let binding, _):
            binding
        }
    }

    var pendingSeatID: SeatID? {
        guard case .pending(_, _, let seatID, _) = self else {
            return nil
        }

        return seatID
    }

    var pendingMIMETypes: [MIMEType] {
        guard case .pending(_, _, _, let mimeTypes) = self else {
            return []
        }

        return mimeTypes
    }

    var snapshot: DataOfferSnapshot? {
        guard case .active(_, _, let snapshot) = self else {
            return nil
        }

        return snapshot
    }

    mutating func appendPendingMIMEType(_ mimeType: MIMEType) {
        guard case .pending(let handle, let binding, let seatID, var mimeTypes) = self else {
            return
        }
        guard !mimeTypes.contains(mimeType) else {
            return
        }

        mimeTypes.append(mimeType)
        self = .pending(
            handle: handle,
            binding: binding,
            seatID: seatID,
            mimeTypes: mimeTypes
        )
    }

    mutating func markActive(id offerID: DataOfferID) throws {
        guard case .pending(let handle, let binding, let seatID, let mimeTypes) = self else {
            return
        }

        self = .active(
            handle: handle,
            binding: binding,
            snapshot: try DataOfferSnapshot(
                id: offerID,
                role: .selection(seatID: seatID),
                mimeTypes: mimeTypes
            )
        )
    }
}

private struct RuntimePrimarySelectionSource {
    let id: DataSourceID
    let binding: any PrimarySelectionSourceBinding
    let payloads: DataTransferSourcePayloadSet
    let snapshot: DataSourceSnapshot

    init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        binding sourceBinding: any PrimarySelectionSourceBinding,
        payloads sourcePayloads: DataTransferSourcePayloadSet
    ) throws {
        guard sourceBinding.id == sourceID else {
            throw DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                expected: sourceID,
                actual: sourceBinding.id
            )
        }

        id = sourceID
        binding = sourceBinding
        payloads = sourcePayloads
        snapshot = try DataSourceSnapshot(
            id: sourceID,
            seatID: sourceSeatID,
            mimeTypes: sourcePayloads.mimeTypes
        )
    }
}

package final class PrimarySelectionController {
    package let backend: any PrimarySelectionControllerBackend
    private var deviceBindings: [SeatID: any PrimarySelectionDeviceBinding] = [:]
    private var offerIDsByHandle: [RawPrimarySelectionOfferHandle: DataOfferID] = [:]
    private var offersByID: [DataOfferID: RuntimePrimarySelectionOffer] = [:]
    private var selectionBySeat: [SeatID: PrimarySelectionSelectionState] = [:]
    private var sourcesByID: [DataSourceID: RuntimePrimarySelectionSource] = [:]
    private var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    private var pendingCallbackFailures: [DataTransferCallbackFailure] = []
    private var pendingEvents: [DataTransferEvent] = []
    private var nextOfferID: UInt64 = 1
    private var nextSourceID: UInt64 = 1

    package init(connection rawConnection: RawDisplayConnection) {
        backend = LivePrimarySelectionControllerBackend(connection: rawConnection)
    }

    package init(backend controllerBackend: any PrimarySelectionControllerBackend) {
        controllerBackend.preconditionIsOwnerThread()
        backend = controllerBackend
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
                PrimarySelectionOfferIdentity(offerID)
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
        let sourceBinding = try backend.createPrimarySelectionSource(id: sourceID) {
            [weak self] event in
            self?.handleSourceEvent(event, sourceID: sourceID)
        }
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
            pendingEvents.append(
                .primarySelectionChanged(PrimarySelectionEvent(seatID: seatID, offerID: nil))
            )
        } catch {
            sourceBinding.destroy()
            sourcesByID[sourceID] = nil
            throw error
        }

        guard let source = sourcesByID[sourceID]?.snapshot else {
            throw DataTransferError.unknownPrimarySelectionSourceIdentity(
                PrimarySelectionSourceIdentity(sourceID)
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
        cleanupSelection(selectionBySeat[seatID] ?? .none)
        selectionBySeat[seatID] = PrimarySelectionSelectionState.none
        pendingEvents.append(
            .primarySelectionChanged(PrimarySelectionEvent(seatID: seatID, offerID: nil))
        )
    }

    package func clearSelectionSource(
        id sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard case .ownedSource(sourceID) = selectionBySeat[seatID] ?? .none else {
            throw DataTransferError.sourceCancelled
        }

        try clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard !pendingCallbackFailures.isEmpty else {
            return
        }

        throw pendingCallbackFailures.removeFirst()
    }
}

private enum PrimarySelectionSelectionState: Equatable {
    case none
    case remoteOffer(DataOfferID)
    case ownedSource(DataSourceID)
}

extension PrimarySelectionController {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        defer { pendingSourceSendRequests.removeAll(keepingCapacity: true) }
        return pendingSourceSendRequests
    }

    package func drainSourceWriteJobs() throws -> [DataTransferSourceWriteJob] {
        let requests = drainSourceSendRequests()
        var jobs: [DataTransferSourceWriteJob] = []

        for index in requests.indices {
            do {
                jobs.append(try requests[index].makeWriteJob())
            } catch {
                discardSourceWriteJobs(jobs)
                discardRemainingSourceSendRequests(requests[(index + 1)...])
                throw error
            }
        }

        return jobs
    }

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
        deviceBindings.removeValue(forKey: seatID)?.release()
        cleanupSelection(selectionBySeat.removeValue(forKey: seatID) ?? .none)

        for (offerID, offer) in offersByID where offer.pendingSeatID == seatID {
            destroyOffer(offerID)
        }
        for (sourceID, source) in sourcesByID where source.snapshot.seatID == seatID {
            cancelSource(sourceID)
        }
    }

    private func handleDeviceEvent(_ event: RawPrimarySelectionDeviceEvent, seatID: SeatID) {
        do {
            switch event {
            case .dataOffer(let handle):
                try handleDataOffer(handle, seatID: seatID)
            case .selection(nil):
                cleanupSelection(selectionBySeat[seatID] ?? .none)
                selectionBySeat[seatID] = PrimarySelectionSelectionState.none
                pendingEvents.append(
                    .primarySelectionChanged(
                        PrimarySelectionEvent(seatID: seatID, offerID: nil)
                    )
                )
            case .selection(.some(let handle)):
                try handleSelection(handle: handle, seatID: seatID)
            }
        } catch {
            recordCallbackError(error, context: .dataDevice(seatID))
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

            let mimeType = try MIMEType(rawMimeType ?? "")
            guard var offer = offersByID[offerID] else {
                throw DataTransferError.unknownPrimarySelectionOfferIdentity(
                    PrimarySelectionOfferIdentity(offerID)
                )
            }
            offer.appendPendingMIMEType(mimeType)
            offersByID[offerID] = offer
        } catch {
            recordCallbackError(
                error,
                context: .primarySelectionOffer(PrimarySelectionOfferIdentity(offerID))
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
                PrimarySelectionOfferIdentity(offerID)
            )
        }
        if let snapshot = offer.snapshot {
            guard snapshot.role.seatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: ClipboardOfferIdentity(offerID),
                    expected: seatID,
                    actual: snapshot.role.seatID
                )
            }
        } else {
            guard offer.pendingSeatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: ClipboardOfferIdentity(offerID),
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

        cleanupSelection(selectionBySeat[seatID] ?? .none)
        selectionBySeat[seatID] = .remoteOffer(offerID)
        pendingEvents.append(
            .primarySelectionChanged(PrimarySelectionEvent(seatID: seatID, offerID: offerID))
        )
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
                cancelSource(sourceID)
                pendingEvents.append(
                    .primarySelectionSourceCancelled(PrimarySelectionSourceIdentity(sourceID))
                )
            }
        } catch {
            recordCallbackError(
                error,
                context: .primarySelectionSource(PrimarySelectionSourceIdentity(sourceID))
            )
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
                    PrimarySelectionSourceIdentity(sourceID)
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
                DataTransferSourceSendRequest(
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
        guard deviceBindings[seatID] != nil else {
            throw DataTransferError.missingPrimarySelectionDevice(seatID)
        }
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
            cancelSource(sourceID)
            pendingEvents.append(
                .primarySelectionSourceCancelled(PrimarySelectionSourceIdentity(sourceID))
            )
        }
    }

    private func destroyOffer(_ offerID: DataOfferID) {
        guard let offer = offersByID.removeValue(forKey: offerID) else {
            return
        }

        offerIDsByHandle[offer.handle] = nil
        offer.binding.destroy()
    }

    private func cancelSource(_ sourceID: DataSourceID) {
        sourcesByID.removeValue(forKey: sourceID)?.binding.destroy()
        discardPendingSourceSendRequests(for: sourceID)
        for (seatID, selection) in selectionBySeat where selection == .ownedSource(sourceID) {
            selectionBySeat[seatID] = PrimarySelectionSelectionState.none
        }
    }

    private func adoptReadEnd(
        _ descriptors: DataTransferPipeDescriptors
    ) throws -> OwnedFileDescriptor {
        do {
            return try backend.adoptOwnedFileDescriptor(descriptors.readEnd)
        } catch {
            _ = backend.closeFileDescriptor(descriptors.readEnd)
            _ = backend.closeFileDescriptor(descriptors.writeEnd)
            throw error
        }
    }

    private func receiveIntoPipe(
        _ binding: any PrimarySelectionOfferBinding,
        mimeType: MIMEType,
        descriptors: DataTransferPipeDescriptors,
        readEnd: inout OwnedFileDescriptor
    ) throws {
        var rawWriteEnd: Int32? = descriptors.writeEnd
        do {
            var writeEnd = try backend.adoptOwnedFileDescriptor(descriptors.writeEnd)
            rawWriteEnd = nil
            binding.receive(mimeType: mimeType, fd: writeEnd.rawValue)
            try writeEnd.close()
        } catch {
            if let rawWriteEnd {
                _ = backend.closeFileDescriptor(rawWriteEnd)
            }
            do {
                try readEnd.close()
            } catch {
                _ = error
            }
            throw error
        }
    }

    private func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        switch backend.closeFileDescriptor(descriptor) {
        case .closed:
            return
        case .failed(let error):
            throw DataTransferError.closeFileDescriptor(error)
        }
    }

    package func discardPendingSourceSendRequests(for sourceID: DataSourceID) {
        var remainingRequests: [DataTransferSourceSendRequest] = []
        for request in drainSourceSendRequests() {
            if request.source == .primarySelection(sourceID) {
                do {
                    try request.close()
                } catch {
                    recordCallbackError(
                        error,
                        context: .primarySelectionSource(
                            PrimarySelectionSourceIdentity(sourceID)
                        )
                    )
                }
            } else {
                remainingRequests.append(request)
            }
        }

        pendingSourceSendRequests = remainingRequests
    }

    private func discardSourceWriteJobs(_ jobs: [DataTransferSourceWriteJob]) {
        for job in jobs {
            _ = job.closeAsCancelled()
        }
    }

    private func discardRemainingSourceSendRequests(
        _ requests: ArraySlice<DataTransferSourceSendRequest>
    ) {
        for request in requests {
            do {
                try request.close()
            } catch {
                recordCallbackError(error, context: .sourceWrite(request.source.diagnosticSource))
            }
        }
    }

    private func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        pendingCallbackFailures.append(
            DataTransferCallbackFailure(
                context: context,
                error: Self.dataTransferCallbackError(error)
            )
        )
    }

    private static func dataTransferCallbackError(_ error: any Error) -> DataTransferError {
        (error as? DataTransferError)
            ?? .callbackFailure(
                .backend(
                    type: String(describing: type(of: error)),
                    description: String(describing: error)
                )
            )
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sorted { $0.rawValue < $1.rawValue }
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
