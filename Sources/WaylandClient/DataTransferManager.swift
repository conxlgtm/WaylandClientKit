import WaylandRaw

package struct DataTransferSelectionChange: Equatable, Sendable {
    package let seatID: SeatID
    package let offerID: DataOfferID?
}

package protocol DataTransferDeviceBinding: AnyObject {
    var seatID: SeatID { get }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial)
    func release()
}

package protocol DataTransferOfferBinding: AnyObject {
    var id: DataOfferID { get }

    func receive(mimeType: MIMEType, fd: Int32)
    func destroy()
}

package protocol DataTransferSourceBinding: AnyObject {
    var id: DataSourceID { get }

    func offer(mimeType: MIMEType)
    func destroy()
}

package struct DataTransferPipeDescriptors: Equatable, Sendable {
    package let readEnd: Int32
    package let writeEnd: Int32
}

package protocol DataTransferManagerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func bindDataDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawDataDeviceEvent) -> Void
    ) throws -> any DataTransferDeviceBinding
    func adoptDataOffer(
        handle: RawDataOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawDataOfferEvent) -> Void
    ) throws -> any DataTransferOfferBinding
    func createDataSource(
        id: DataSourceID,
        onEvent: @escaping (RawDataSourceEvent) -> Void
    ) throws -> any DataTransferSourceBinding
    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor
    func closeFileDescriptor(_ descriptor: Int32) -> Int32
}

package final class DataTransferManager {
    package let backend: any DataTransferManagerBackend
    package var state = DataTransferState()
    package var deviceBindings: [SeatID: any DataTransferDeviceBinding] = [:]
    package var offerBindingsByID: [DataOfferID: any DataTransferOfferBinding] = [:]
    package var sourceBindingsByID: [DataSourceID: any DataTransferSourceBinding] = [:]
    package var sourceProvidersByID: [DataSourceID: DataTransferSourceProvider] = [:]
    package var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    private var offerIDsByHandle: [RawDataOfferHandle: DataOfferID] = [:]
    private var pendingOfferMimeTypesByID: [DataOfferID: [MIMEType]] = [:]
    private var pendingOfferSeatIDsByID: [DataOfferID: SeatID] = [:]
    package var pendingCallbackError: (any Error)?
    private var nextOfferID: UInt64 = 1
    package var nextSourceID: UInt64 = 1

    package private(set) var selectionChanges: [DataTransferSelectionChange] = []
    package private(set) var sourceCancellations: [DataSourceID] = []
    package private(set) var pendingEvents: [DataTransferEvent] = []

    package init(connection rawConnection: RawDisplayConnection) {
        backend = LiveDataTransferManagerBackend(connection: rawConnection)
    }

    package init(backend dataTransferBackend: any DataTransferManagerBackend) {
        dataTransferBackend.preconditionIsOwnerThread()
        backend = dataTransferBackend
    }

    package var seatSnapshots: [DataTransferSeatSnapshot] {
        state.seatSnapshots
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        state.offerSnapshots
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        state.sourceSnapshots
    }

    package func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let desiredSeats = Set(seatIDs)
        let currentSeats = Set(state.seatSnapshots.map(\.seatID))
        for seatID in Self.sortedSeatIDs(currentSeats.subtracting(desiredSeats)) {
            try apply(.seatRemoved(seatID))
        }
        for seatID in Self.sortedSeatIDs(desiredSeats.subtracting(currentSeats)) {
            try apply(.seatAvailable(seatID))
        }
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard let error = pendingCallbackError else {
            return
        }

        pendingCallbackError = nil
        throw error
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    package func apply(_ action: DataTransferAction) throws {
        var nextState = state
        let plan = try nextState.reduce(action)
        nextState = plan.state

        do {
            try interpret(plan.effects, nextState: &nextState)
        } catch {
            rollbackBindings(for: state)
            throw error
        }

        state = nextState
    }

    private func interpret(
        _ effects: [DataTransferEffect],
        nextState: inout DataTransferState
    ) throws {
        for effect in effects {
            try interpret(effect, nextState: &nextState)
        }
    }

    private func interpret(
        _ effect: DataTransferEffect,
        nextState: inout DataTransferState
    ) throws {
        switch effect {
        case .bindDataDevice(let seatID):
            try bindDataDevice(for: seatID, nextState: &nextState)
        case .releaseDataDevice(let seatID):
            deviceBindings.removeValue(forKey: seatID)?.release()
            destroyPendingOfferBindings(for: seatID)
        case .destroyOffer(let offerID):
            destroyOfferBinding(offerID)
        case .cancelSource(let sourceID):
            destroySourceBinding(sourceID)
        case .publishSelectionChanged(let seatID, let offerID):
            selectionChanges.append(
                DataTransferSelectionChange(seatID: seatID, offerID: offerID)
            )
            pendingEvents.append(
                .selectionChanged(
                    ClipboardSelectionEvent(seatID: seatID, offerID: offerID)
                )
            )
        case .publishSourceCancelled(let sourceID):
            sourceCancellations.append(sourceID)
            pendingEvents.append(.sourceCancelled(ClipboardSourceIdentity(sourceID)))
        }
    }

    private func bindDataDevice(
        for seatID: SeatID,
        nextState: inout DataTransferState
    ) throws {
        guard deviceBindings[seatID] == nil else {
            return
        }

        let binding = try backend.bindDataDevice(for: seatID) { [weak self] event in
            self?.handleDataDeviceEvent(event, seatID: seatID)
        }
        do {
            nextState = try nextState.reduce(.dataDeviceBound(seatID)).state
        } catch {
            binding.release()
            throw error
        }

        deviceBindings[seatID] = binding
    }

    private func handleDataDeviceEvent(_ event: RawDataDeviceEvent, seatID: SeatID) {
        do {
            switch event {
            case .dataOffer(let handle):
                try handleDataOffer(handle, seatID: seatID)
            case .selection(nil):
                try apply(.selectionChanged(seatID: seatID, offerID: nil))
            case .selection(.some(let handle)):
                try handleSelection(handle: handle, seatID: seatID)
            default:
                break
            }
        } catch {
            pendingCallbackError = error
        }
    }

    private func handleDataOffer(_ handle: RawDataOfferHandle?, seatID: SeatID) throws {
        guard let handle else {
            throw DataTransferError.unknownOffer
        }
        guard offerIDsByHandle[handle] == nil else {
            throw DataTransferError.duplicateOffer
        }

        let offerID = allocateOfferID()
        let handleOfferEvent: (RawDataOfferEvent) -> Void = { [weak self] event in
            self?.handleDataOfferEvent(event, offerID: offerID)
        }
        let binding = try backend.adoptDataOffer(
            handle: handle,
            id: offerID,
            onEvent: handleOfferEvent
        )
        offerIDsByHandle[handle] = offerID
        offerBindingsByID[offerID] = binding
        pendingOfferMimeTypesByID[offerID] = []
        pendingOfferSeatIDsByID[offerID] = seatID
    }

    private func handleDataOfferEvent(_ event: RawDataOfferEvent, offerID: DataOfferID) {
        do {
            guard case .offer(let rawMimeType) = event else {
                return
            }

            let mimeType = try MIMEType(rawMimeType ?? "")
            if state.offerSnapshot(offerID) != nil {
                try apply(.offerMimeType(id: offerID, mimeType: mimeType))
            } else if pendingOfferMimeTypesByID[offerID]?.contains(mimeType) == false {
                pendingOfferMimeTypesByID[offerID]?.append(mimeType)
            }
        } catch {
            pendingCallbackError = error
        }
    }

    private func handleSelection(handle: RawDataOfferHandle, seatID: SeatID) throws {
        guard let offerID = offerIDsByHandle[handle] else {
            throw DataTransferError.unknownOffer
        }

        if let existingOffer = state.offerSnapshot(offerID) {
            guard existingOffer.role.seatID == seatID else {
                throw DataTransferError.unknownOffer
            }
        } else {
            guard pendingOfferSeatIDsByID[offerID] == seatID else {
                throw DataTransferError.unknownOffer
            }

            try apply(.offerCreated(id: offerID, role: .selection(seatID: seatID)))
            for mimeType in pendingOfferMimeTypesByID[offerID] ?? [] {
                try apply(.offerMimeType(id: offerID, mimeType: mimeType))
            }
            pendingOfferMimeTypesByID[offerID] = nil
            pendingOfferSeatIDsByID[offerID] = nil
        }

        try apply(.selectionChanged(seatID: seatID, offerID: offerID))
    }

    private func destroyOfferBinding(_ offerID: DataOfferID) {
        offerBindingsByID.removeValue(forKey: offerID)?.destroy()
        pendingOfferMimeTypesByID[offerID] = nil
        pendingOfferSeatIDsByID[offerID] = nil
        for (handle, handleOfferID) in offerIDsByHandle where handleOfferID == offerID {
            offerIDsByHandle[handle] = nil
        }
    }

    private func destroySourceBinding(_ sourceID: DataSourceID) {
        sourceBindingsByID.removeValue(forKey: sourceID)?.destroy()
        sourceProvidersByID[sourceID] = nil
        discardPendingSourceSendRequests(for: sourceID)
    }

    private func destroyPendingOfferBindings(for seatID: SeatID) {
        let pendingOfferIDs =
            pendingOfferSeatIDsByID
            .filter { $0.value == seatID }
            .map(\.key)

        for offerID in pendingOfferIDs {
            destroyOfferBinding(offerID)
        }
    }

    private func rollbackBindings(for committedState: DataTransferState) {
        let liveSeats = Set(committedState.seatSnapshots.map(\.seatID))
        for seatID in deviceBindings.keys where !liveSeats.contains(seatID) {
            deviceBindings.removeValue(forKey: seatID)?.release()
        }
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sorted { $0.rawValue < $1.rawValue }
    }

    private func allocateOfferID() -> DataOfferID {
        defer { nextOfferID += 1 }
        return DataOfferID(rawValue: nextOfferID)
    }
}
