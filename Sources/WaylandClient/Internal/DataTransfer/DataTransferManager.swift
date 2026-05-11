import WaylandRaw

package protocol DataTransferDeviceBinding: AnyObject {
    var seatID: SeatID { get }
    var protocolVersion: RawVersion { get }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial)
    func startDrag(
        source: any DataTransferSourceBinding,
        origin: any DataTransferDragOriginBinding,
        icon: DragIcon,
        serial: InputSerial
    )
    func release()
}

package protocol DataTransferDragOriginBinding: AnyObject {}

package protocol DataTransferOfferBinding: AnyObject {
    var id: DataOfferID { get }
    var protocolVersion: RawVersion { get }

    func accept(serial: InputSerial, mimeType: MIMEType?)
    func receive(mimeType: MIMEType, fd: Int32)
    func setDragActions(_ actions: DragActionSet, preferredAction: DragAction)
    func finish()
    func destroy()
}

package protocol DataTransferSourceBinding: AnyObject {
    var id: DataSourceID { get }
    var protocolVersion: RawVersion { get }

    func offer(mimeType: MIMEType)
    func setDragActions(_ actions: DragActionSet)
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

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

package final class DataTransferManager {
    package let backend: any DataTransferManagerBackend
    let eventQueue: DataTransferEventQueue
    let surfaceTargetResolver: (RawObjectID?) -> InputEventTarget
    var store = DataTransferStore()
    private var nextOfferID: UInt64 = 1
    package var nextSourceID: UInt64 = 1

    package init(
        connection rawConnection: RawDisplayConnection,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue(),
        surfaceTargetResolver targetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            DataTransferManager.defaultTarget
    ) {
        backend = LiveDataTransferManagerBackend(connection: rawConnection)
        eventQueue = dataTransferEventQueue
        surfaceTargetResolver = targetResolver
    }

    package init(
        backend dataTransferBackend: any DataTransferManagerBackend,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue(),
        surfaceTargetResolver targetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            DataTransferManager.defaultTarget
    ) {
        dataTransferBackend.preconditionIsOwnerThread()
        backend = dataTransferBackend
        eventQueue = dataTransferEventQueue
        surfaceTargetResolver = targetResolver
    }

    package func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let desiredSeats = Set(seatIDs)
        let currentSeats = Set(store.seatSnapshots.map(\.seatID))
        for seatID in Self.sortedSeatIDs(currentSeats.subtracting(desiredSeats)) {
            try apply(.seatRemoved(seatID))
        }
        for seatID in Self.sortedSeatIDs(desiredSeats.subtracting(currentSeats)) {
            try apply(.seatAvailable(seatID))
        }

        preconditionInvariantsHold()
    }

    package func apply(_ action: DataTransferAction) throws {
        let plan = try store.transitionPlan(for: action)
        var nextState = plan.state

        try interpret(plan.effects, nextState: &nextState)
        store.replaceState(nextState)
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
            store.removeDeviceBinding(for: seatID)?.release()
            destroyPendingOfferBindings(for: seatID)
        case .destroyOffer(let offerID):
            destroyOfferBinding(offerID)
        case .destroySource(let sourceID):
            destroySourceBindingPreservingPendingSends(sourceID)
        case .cancelSource(let sourceID):
            cancelSourceBinding(sourceID)
        case .publishSelectionChanged(let seatID, let offerID):
            eventQueue.append(
                .clipboardSelectionChanged(
                    ClipboardSelectionEvent(seatID: seatID, offerID: offerID)
                )
            )
        case .publishDragEntered, .publishDragMotion, .publishDragLeft, .publishDragDropped,
            .publishDragOfferChanged, .publishDragSourceCancelled,
            .publishDragSourceTargetChanged, .publishDragSourceActionChanged,
            .publishDragSourceDropPerformed, .publishDragSourceFinished:
            appendDragAndDropEvent(for: effect)
        case .publishSourceCancelled(let sourceID):
            eventQueue.append(.clipboardSourceCancelled(ClipboardSourceIdentity(sourceID)))
        }
    }

    private func bindDataDevice(
        for seatID: SeatID,
        nextState: inout DataTransferState
    ) throws {
        guard store.deviceBinding(for: seatID) == nil else {
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

        store.insertDeviceBinding(binding, for: seatID)
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
                try handleDragEnter(enter, seatID: seatID)
            case .leave:
                try apply(.dragLeft(seatID))
            case .drop:
                try apply(.dragDropped(seatID))
            case .motion(let time, let x, let y):
                try apply(
                    .dragMotion(
                        seatID: seatID,
                        time: WaylandTimestampMilliseconds(rawValue: time),
                        location: DragLocation(x: x.doubleValue, y: y.doubleValue)
                    )
                )
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: .dataDevice(seatID))
        }
    }

    private func handleDataOffer(_ handle: RawDataOfferHandle?, seatID: SeatID) throws {
        guard let handle else {
            throw DataTransferError.missingOfferHandle(seatID: seatID)
        }
        guard !store.hasOffer(handle: handle) else {
            throw DataTransferError.duplicateOfferHandle(
                rawValue: handle.rawValue,
                existingOffer: store.offerID(for: handle).map(ClipboardOfferIdentity.init)
            )
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
        store.insertPendingOffer(
            handle: handle,
            offerID: offerID,
            binding: binding,
            seatID: seatID
        )
    }

    private func handleSelection(handle: RawDataOfferHandle, seatID: SeatID) throws {
        guard let offerID = store.offerID(for: handle) else {
            throw DataTransferError.unknownOfferHandle(
                rawValue: handle.rawValue,
                seatID: seatID
            )
        }

        if let existingOffer = store.offerSnapshot(offerID) {
            guard existingOffer.role.seatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: .clipboard(ClipboardOfferIdentity(offerID)),
                    expected: seatID,
                    actual: existingOffer.role.seatID
                )
            }
        } else {
            guard let runtimeOffer = store.runtimeOffer(offerID) else {
                throw DataTransferError.unknownOfferIdentity(ClipboardOfferIdentity(offerID))
            }
            guard runtimeOffer.pendingSeatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: .clipboard(ClipboardOfferIdentity(offerID)),
                    expected: seatID,
                    actual: runtimeOffer.pendingSeatID
                )
            }
            guard !runtimeOffer.pendingMIMETypes.isEmpty else {
                throw DataTransferError.emptyDataOffer
            }

            try apply(.offerCreated(id: offerID, role: .selection(seatID: seatID)))
            for mimeType in runtimeOffer.pendingMIMETypes {
                try apply(.offerMimeType(id: offerID, mimeType: mimeType))
            }
            _ = try store.markOfferActive(offerID)
        }

        try apply(.selectionChanged(seatID: seatID, offerID: offerID))
    }

    private func destroyOfferBinding(_ offerID: DataOfferID) {
        if let runtimeOffer = store.removeOffer(offerID) {
            runtimeOffer.binding.destroy()
        }
    }

    private func destroySourceBinding(_ sourceID: DataSourceID) {
        store.removeSource(sourceID)?.binding.destroy()
    }

    private func destroySourceBindingPreservingPendingSends(_ sourceID: DataSourceID) {
        store.detachSourcePreservingPendingSends(sourceID)?.binding.destroy()
    }

    private func cancelSourceBinding(_ sourceID: DataSourceID) {
        destroySourceBinding(sourceID)
        discardPendingSourceSendRequests(for: sourceID)
    }

    private func destroyPendingOfferBindings(for seatID: SeatID) {
        for offerID in store.pendingOfferIDs(for: seatID) {
            destroyOfferBinding(offerID)
        }
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sorted { $0.rawValue < $1.rawValue }
    }

    private static func sortedOfferIDs(_ offerIDs: Set<DataOfferID>) -> [DataOfferID] {
        offerIDs.sorted { $0.rawValue < $1.rawValue }
    }

    private static func sortedSourceIDs(_ sourceIDs: Set<DataSourceID>) -> [DataSourceID] {
        sourceIDs.sorted { $0.rawValue < $1.rawValue }
    }

    private func allocateOfferID() -> DataOfferID {
        defer { nextOfferID += 1 }
        return DataOfferID(rawValue: nextOfferID)
    }
}

extension DataTransferManager {
    package var seatSnapshots: [DataTransferSeatSnapshot] {
        store.seatSnapshots
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        store.offerSnapshots
    }

    package var offerBindingsByID: [DataOfferID: any DataTransferOfferBinding] {
        var bindings: [DataOfferID: any DataTransferOfferBinding] = [:]
        for (offerID, runtimeOffer) in store.offersByIDForInvariantChecks {
            bindings[offerID] = runtimeOffer.binding
        }
        return bindings
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        store.sourceSnapshots
    }

    package var pendingCallbackError: DataTransferCallbackFailure? {
        store.callbackFailure
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard let error = store.takeCallbackFailure() else {
            return
        }

        throw error
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    func shutdown() {
        backend.preconditionIsOwnerThread()

        for sourceID in Self.sortedSourceIDs(store.sourceIDs) {
            store.removeSource(sourceID)?.binding.destroy()
        }
        for offerID in Self.sortedOfferIDs(store.offerIDs) {
            store.removeOffer(offerID)?.binding.destroy()
        }
        for seatID in Self.sortedSeatIDs(store.boundSeatIDs) {
            store.removeDeviceBinding(for: seatID)?.release()
        }
        discardAllPendingSourceSendRequests()

        store.replaceState(DataTransferState())
        store.discardCallbackFailures()
    }

    package func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        store.recordCallbackFailure(
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
}
