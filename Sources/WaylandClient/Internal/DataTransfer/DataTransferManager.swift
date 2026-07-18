import WaylandRaw

package protocol DataTransferDeviceBinding: AnyObject {
    var protocolVersion: RawVersion { get }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial)
    func startDrag(
        source: any DataTransferSourceBinding,
        origin: any DataTransferDragOriginBinding,
        icon: (any DataTransferDragIconBinding)?,
        serial: InputSerial
    )
    func release()
}

package protocol DataTransferDragOriginBinding: AnyObject {}

package protocol DataTransferDragIconBinding: AnyObject {
    func destroy()
}

package protocol DataTransferOfferResourceBinding: AnyObject, DataTransferReceiveBinding {
    func destroy()
}

package protocol DataTransferSourceResourceBinding: AnyObject {
    var id: DataSourceID { get }

    func offer(mimeType: MIMEType)
    func destroy()
}

package protocol DataTransferOfferBinding: DataTransferOfferResourceBinding {
    var id: DataOfferID { get }
    var protocolVersion: RawVersion { get }

    func accept(serial: InputSerial, mimeType: MIMEType?)
    func setDragActions(_ actions: DragActionSet, preferredAction: DragAction)
    func finish()
}

package protocol DataTransferSourceBinding: DataTransferSourceResourceBinding {
    var protocolVersion: RawVersion { get }

    func setDragActions(_ actions: DragActionSet)
    func createToplevelDrag(manager: RawXDGToplevelDragManager) throws -> RawXDGToplevelDrag
    func attachDragIcon(_ icon: (any DataTransferDragIconBinding)?)
}

package struct DataTransferPipeDescriptors: Equatable, Sendable {
    package let readEnd: Int32
    package let writeEnd: Int32
}

package protocol DataTransferManagerBackend: AnyObject, DataTransferOfferReceiveBackend {
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
    func prepareDragIcon(_ icon: DragIcon) throws -> (any DataTransferDragIconBinding)?
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

package final class DataTransferManager {
    package let backend: any DataTransferManagerBackend
    let eventQueue: DataTransferEventQueue
    let surfaceTargetResolver: (RawObjectID?) -> InputEventTarget
    package var sourceWillCancel: (DataSourceID) -> Void
    var store = DataTransferStore()
    private var offerIDs = IDGenerator<DataOfferID>()
    package var sourceIDs = IDGenerator<DataSourceID>()
    var isShutdown = false

    package init(
        connection rawConnection: RawDisplayConnection,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue(),
        surfaceTargetResolver targetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            DataTransferManager.defaultTarget,
        sourceWillCancel cancellationHandler: @escaping (DataSourceID) -> Void = { _ in () }
    ) {
        backend = LiveDataTransferManagerBackend(connection: rawConnection)
        eventQueue = dataTransferEventQueue
        surfaceTargetResolver = targetResolver
        sourceWillCancel = cancellationHandler
    }

    package init(
        backend dataTransferBackend: any DataTransferManagerBackend,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue(),
        surfaceTargetResolver targetResolver: @escaping (RawObjectID?) -> InputEventTarget =
            DataTransferManager.defaultTarget,
        sourceWillCancel cancellationHandler: @escaping (DataSourceID) -> Void = { _ in () }
    ) {
        dataTransferBackend.preconditionIsOwnerThread()
        backend = dataTransferBackend
        eventQueue = dataTransferEventQueue
        surfaceTargetResolver = targetResolver
        sourceWillCancel = cancellationHandler
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
        try apply([action])
    }

    func apply(
        _ actions: [DataTransferAction],
        insertingSources sourceRecords: [RuntimeDataSource] = [],
        activatingOffers activatedOfferIDs: [DataOfferID] = []
    ) throws {
        let prepared = try prepareTransition(
            actions,
            insertingSources: sourceRecords,
            activatingOffers: activatedOfferIDs
        )
        let postCommitActions = store.commit(prepared)
        preconditionInvariantsHold()
        performPostCommitActions(postCommitActions)
    }

    private func prepareTransition(
        _ actions: [DataTransferAction],
        insertingSources sourceRecords: [RuntimeDataSource],
        activatingOffers activatedOfferIDs: [DataOfferID]
    ) throws -> PreparedDataTransferTransition {
        var plan = try store.transitionPlan(for: actions)
        for offerID in activatedOfferIDs {
            guard let offer = store.runtimeOffer(offerID), case .pending = offer else {
                throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
            }
        }

        var preparedDevices: [PreparedDataTransferDeviceBinding] = []
        do {
            for effect in plan.effects {
                guard case .bindDataDevice(let seatID)? = effect.runtimeSideEffect else {
                    continue
                }
                guard store.deviceBinding(for: seatID) == nil else {
                    continue
                }

                let binding = try backend.bindDataDevice(for: seatID) { [weak self] event in
                    self?.handleDataDeviceEvent(event, seatID: seatID)
                }
                preparedDevices.append(
                    PreparedDataTransferDeviceBinding(
                        seatID: seatID,
                        binding: binding
                    )
                )

                let boundPlan = try plan.state.reduce(.dataDeviceBound(seatID))
                precondition(
                    boundPlan.effects.isEmpty,
                    "binding a prepared data device unexpectedly produced effects"
                )
                plan = DataTransferTransitionPlan(
                    state: boundPlan.state,
                    effects: plan.effects
                )
            }
        } catch {
            for preparedDevice in preparedDevices.reversed() {
                preparedDevice.binding.release()
            }
            throw error
        }

        return PreparedDataTransferTransition(
            state: plan.state,
            effects: plan.effects,
            deviceBindings: preparedDevices,
            sourceRecords: sourceRecords,
            activatedOfferIDs: activatedOfferIDs
        )
    }

    private func performPostCommitActions(_ actions: [DataTransferPostCommitAction]) {
        for action in actions {
            switch action {
            case .releaseDevice(let binding):
                binding.release()
            case .destroyOffer(let binding):
                binding.destroy()
            case .destroySource(let binding):
                binding.destroy()
            case .cancelSource(let sourceID, let binding, let requests):
                sourceWillCancel(sourceID)
                binding?.destroy()
                discardSourceSendRequests(requests)
            case .publish(let event):
                eventQueue.append(event)
            }
        }
    }

    private func handleDataDeviceEvent(_ event: RawDataDeviceEvent, seatID: SeatID) {
        guard !isShutdown else { return }
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
                        location: DragLocation(waylandX: x, waylandY: y)
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
                    offer: .clipboard(offerID.clipboardIdentity),
                    expected: seatID,
                    actual: existingOffer.role.seatID
                )
            }
        } else {
            guard let runtimeOffer = store.runtimeOffer(offerID) else {
                throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
            }
            guard runtimeOffer.pendingSeatID == seatID else {
                throw DataTransferError.mismatchedOfferSeat(
                    offer: .clipboard(offerID.clipboardIdentity),
                    expected: seatID,
                    actual: runtimeOffer.pendingSeatID
                )
            }
            guard !runtimeOffer.pendingMIMETypes.isEmpty else {
                throw DataTransferError.emptyDataOffer
            }

            var actions: [DataTransferAction] = [
                .offerCreated(id: offerID, role: .selection(seatID: seatID))
            ]
            actions.append(
                contentsOf: runtimeOffer.pendingMIMETypes.map { mimeType in
                    .offerMimeType(id: offerID, mimeType: mimeType)
                }
            )
            actions.append(.selectionChanged(seatID: seatID, offerID: offerID))
            try apply(actions, activatingOffers: [offerID])
            return
        }

        try apply(.selectionChanged(seatID: seatID, offerID: offerID))
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sortedByRawValue()
    }

    private func allocateOfferID() -> DataOfferID {
        offerIDs.next()
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
        guard !isShutdown else { return }
        isShutdown = true

        let committed = store.commitShutdown()
        preconditionInvariantsHold()

        for source in committed.sources {
            source.binding.destroy()
        }
        for offer in committed.offers {
            offer.binding.destroy()
        }
        for device in committed.devices {
            device.release()
        }
        discardSourceSendRequestsDuringShutdown(committed.pendingSourceSendRequests)
    }

    package func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        guard !isShutdown else { return }
        store.recordCallbackFailure(
            DataTransferCallbackFailure(
                context: context,
                error: DataTransferError(callbackBackendError: error)
            )
        )
    }
}
