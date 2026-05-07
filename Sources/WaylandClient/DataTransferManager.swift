import WaylandRaw

package struct DataTransferSelectionChange: Equatable, Sendable {
    package let seatID: SeatID
    package let offerID: DataOfferID?
}

package enum DataTransferCallbackContext: Equatable, Sendable {
    case dataDevice(SeatID)
    case dataOffer(DataOfferID)
    case dataSource(DataSourceID)
}

package struct DataTransferCallbackFailure:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    package let context: DataTransferCallbackContext
    package let error: DataTransferError

    package var description: String {
        "\(context): \(error.description)"
    }
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

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }

    func closeFileDescriptor(_ descriptor: Int32) -> Int32
}

package final class DataTransferManager {
    package let backend: any DataTransferManagerBackend
    package var state = DataTransferState()
    var runtime = DataTransferRuntimeStore()
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

        preconditionInvariantsHold()
    }

    package func apply(_ action: DataTransferAction) throws {
        var nextState = state
        let plan = try nextState.reduce(action)
        nextState = plan.state

        try interpret(plan.effects, nextState: &nextState)
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
            runtime.removeDeviceBinding(for: seatID)?.release()
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
        guard runtime.deviceBinding(for: seatID) == nil else {
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

        runtime.insertDeviceBinding(binding, for: seatID)
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
            case .enter(let enter):
                try handleUnsupportedDragEnter(enter, seatID: seatID)
            case .leave, .drop:
                break
            case .motion:
                break
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: .dataDevice(seatID))
        }
    }

    private func handleDataOffer(_ handle: RawDataOfferHandle?, seatID: SeatID) throws {
        guard let handle else {
            throw DataTransferError.unknownOffer
        }
        guard !runtime.hasOffer(handle: handle) else {
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
        runtime.insertPendingOffer(
            handle: handle,
            offerID: offerID,
            binding: binding,
            seatID: seatID
        )
    }

    private func handleDataOfferEvent(_ event: RawDataOfferEvent, offerID: DataOfferID) {
        do {
            guard case .offer(let rawMimeType) = event else {
                return
            }

            let mimeType = try MIMEType(rawMimeType ?? "")
            if state.offerSnapshot(offerID) != nil {
                try apply(.offerMimeType(id: offerID, mimeType: mimeType))
            } else {
                try runtime.appendPendingMIMEType(mimeType, offerID: offerID)
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: .dataOffer(offerID))
        }
    }

    private func handleSelection(handle: RawDataOfferHandle, seatID: SeatID) throws {
        guard let offerID = runtime.offerID(for: handle) else {
            throw DataTransferError.unknownOffer
        }

        if let existingOffer = state.offerSnapshot(offerID) {
            guard existingOffer.role.seatID == seatID else {
                throw DataTransferError.unknownOffer
            }
        } else {
            guard let runtimeOffer = runtime.runtimeOffer(offerID) else {
                throw DataTransferError.unknownOffer
            }
            guard runtimeOffer.pendingSeatID == seatID else {
                throw DataTransferError.unknownOffer
            }

            try apply(.offerCreated(id: offerID, role: .selection(seatID: seatID)))
            for mimeType in runtimeOffer.pendingMIMETypes {
                try apply(.offerMimeType(id: offerID, mimeType: mimeType))
            }
            _ = try runtime.markOfferActive(offerID)
        }

        try apply(.selectionChanged(seatID: seatID, offerID: offerID))
    }

    private func destroyOfferBinding(_ offerID: DataOfferID) {
        if let runtimeOffer = runtime.removeOffer(offerID) {
            runtimeOffer.binding.destroy()
        }
    }

    private func destroySourceBinding(_ sourceID: DataSourceID) {
        runtime.removeSource(sourceID)?.binding.destroy()
        discardPendingSourceSendRequests(for: sourceID)
    }

    private func destroyPendingOfferBindings(for seatID: SeatID) {
        for offerID in runtime.pendingOfferIDs(for: seatID) {
            destroyOfferBinding(offerID)
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

extension DataTransferManager {
    package var seatSnapshots: [DataTransferSeatSnapshot] {
        state.seatSnapshots
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        state.offerSnapshots
    }

    package var offerBindingsByID: [DataOfferID: any DataTransferOfferBinding] {
        var bindings: [DataOfferID: any DataTransferOfferBinding] = [:]
        for (offerID, runtimeOffer) in runtime.offersByIDForInvariantChecks {
            bindings[offerID] = runtimeOffer.binding
        }
        return bindings
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        state.sourceSnapshots
    }

    package var pendingCallbackError: DataTransferCallbackFailure? {
        runtime.callbackFailure
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard let error = runtime.takeCallbackFailure() else {
            return
        }

        throw error.error
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    package func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        runtime.recordCallbackFailure(
            DataTransferCallbackFailure(
                context: context,
                error: Self.dataTransferCallbackError(error)
            )
        )
    }

    private static func dataTransferCallbackError(_ error: any Error) -> DataTransferError {
        (error as? DataTransferError) ?? .unavailable
    }

    private func handleUnsupportedDragEnter(
        _ enter: RawDataDeviceEnter,
        seatID: SeatID
    ) throws {
        guard let handle = enter.offer else {
            return
        }
        guard let offerID = runtime.offerID(for: handle) else {
            throw DataTransferError.unknownOffer
        }

        guard state.offerSnapshot(offerID) == nil else {
            throw DataTransferError.unknownOffer
        }
        guard runtime.runtimeOffer(offerID)?.pendingSeatID == seatID else {
            throw DataTransferError.unknownOffer
        }

        destroyOfferBinding(offerID)
    }
}
