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
    var pendingDragMetadataByOfferID: [DataOfferID: PendingDragOfferMetadata] = [:]
    var isShutdown = false
    lazy var selectionEngine = SelectionEngine(
        kind: .clipboard,
        backend: ClipboardSelectionEngineBackend(
            backend: backend,
            onDragDeviceEvent: { [weak self] event, seatID in
                self?.handleDragDataDeviceEvent(event, seatID: seatID)
            },
            onDragOfferEvent: { [weak self] event, offerID in
                self?.handleDragOfferEvent(event, offerID: offerID)
            }
        ),
        eventQueue: eventQueue,
        hooks: SelectionEngineHooks(
            sourceWillCancel: { [weak self] sourceID in
                self?.sourceWillCancel(sourceID)
            },
            offerDidDestroy: { [weak self] offerID in
                self?.pendingDragMetadataByOfferID[offerID] = nil
            },
            unownedOfferEvent: { [weak self] event, offerID in
                self?.handleTransferredOfferEvent(event, offerID: offerID) ?? false
            },
            externalOfferID: { [weak self] handle in
                guard case .clipboard(let rawHandle) = handle else { return nil }
                return self?.store.offerID(for: rawHandle)
            },
            externalSourceIDs: { [weak self] in
                self?.store.sourceIDs ?? []
            }
        )
    )

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
            let postCommitActions = try commit([.seatRemoved(seatID)])
            selectionEngine.removeSeat(seatID)
            preconditionInvariantsHold()
            performPostCommitActions(postCommitActions)
        }
        for seatID in Self.sortedSeatIDs(desiredSeats.subtracting(currentSeats)) {
            try selectionEngine.addSeat(seatID)
            do {
                try apply(.seatAvailable(seatID))
            } catch {
                selectionEngine.removeSeat(seatID)
                throw error
            }
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
        let postCommitActions = try commit(
            actions,
            insertingSources: sourceRecords,
            activatingOffers: activatedOfferIDs
        )
        preconditionInvariantsHold()
        performPostCommitActions(postCommitActions)
    }

    private func commit(
        _ actions: [DataTransferAction],
        insertingSources sourceRecords: [RuntimeDataSource] = [],
        activatingOffers activatedOfferIDs: [DataOfferID] = []
    ) throws -> [DataTransferPostCommitAction] {
        let prepared = try prepareTransition(
            actions,
            insertingSources: sourceRecords,
            activatingOffers: activatedOfferIDs
        )
        return store.commit(prepared).map { action in
            switch action {
            case .destroySource(let binding):
                selectionEngine.detachExternalSourcePreservingPendingSends(binding.id)
                return action
            case .cancelSource(let sourceID, let binding, let requests):
                return .cancelSource(
                    id: sourceID,
                    binding: binding,
                    requests: requests + selectionEngine.removeSourceSendRequests(for: sourceID)
                )
            case .destroyOffer, .publish:
                return action
            }
        }
    }

    private func prepareTransition(
        _ actions: [DataTransferAction],
        insertingSources sourceRecords: [RuntimeDataSource],
        activatingOffers activatedOfferIDs: [DataOfferID]
    ) throws -> PreparedDataTransferTransition {
        let plan = try store.transitionPlan(for: actions)
        for offerID in activatedOfferIDs {
            guard let offer = store.runtimeOffer(offerID), case .pending = offer else {
                throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
            }
        }

        return PreparedDataTransferTransition(
            state: plan.state,
            effects: plan.effects,
            sourceRecords: sourceRecords,
            activatedOfferIDs: activatedOfferIDs
        )
    }

    private func performPostCommitActions(_ actions: [DataTransferPostCommitAction]) {
        for action in actions {
            switch action {
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

    func handleDragDataDeviceEvent(_ event: RawDataDeviceEvent, seatID: SeatID) {
        guard !isShutdown else { return }
        do {
            switch event {
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
            case .dataOffer, .selection:
                preconditionFailure("selection event bypassed the shared selection engine")
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: .dataDevice(seatID))
        }
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sortedByRawValue()
    }
}

extension DataTransferManager {
    package var seatSnapshots: [DataTransferSeatSnapshot] {
        store.seatSnapshots.map { seat in
            let isBound = selectionEngine.boundSeatIDs.contains(seat.seatID)
            return DataTransferSeatSnapshot(
                seatID: seat.seatID,
                device: isBound
                    ? .bound(selection: selectionEngine.selectionState(for: seat.seatID))
                    : .unbound,
                dragAndDropOfferID: seat.dragAndDropOfferID
            )
        }
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        (selectionEngine.offerSnapshots + store.offerSnapshots).sortedByRawValue(\.id)
    }

    package var offerBindingsByID: [DataOfferID: any DataTransferOfferBinding] {
        var bindings: [DataOfferID: any DataTransferOfferBinding] = [:]
        for (offerID, runtimeOffer) in store.offersByIDForInvariantChecks {
            bindings[offerID] = runtimeOffer.binding
        }
        for offer in selectionEngine.offerSnapshots {
            guard
                let binding = selectionEngine.offerBinding(offer.id)
                    as? any DataTransferOfferBinding
            else {
                preconditionFailure("clipboard offer is not backed by a data-device offer")
            }
            bindings[offer.id] = binding
        }
        return bindings
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        (selectionEngine.sourceSnapshots + store.sourceSnapshots).sortedByRawValue(\.id)
    }

    package var pendingCallbackError: DataTransferCallbackFailure? {
        selectionEngine.pendingCallbackError
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        try selectionEngine.throwPendingCallbackErrorIfAny()
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    func shutdown() {
        backend.preconditionIsOwnerThread()
        guard !isShutdown else { return }
        isShutdown = true

        let committedDragState = store.commitShutdown()
        let committedSelectionState = selectionEngine.commitShutdown()
        pendingDragMetadataByOfferID.removeAll(keepingCapacity: false)
        preconditionInvariantsHold()

        for source in committedDragState.sources {
            source.binding.destroy()
        }
        for source in committedSelectionState.sources {
            source.destroy()
        }
        for offer in committedDragState.offers {
            offer.binding.destroy()
        }
        for offer in committedSelectionState.offers {
            offer.binding.destroy()
        }
        for device in committedSelectionState.devices {
            device.release()
        }
        DataTransferSourceSendLifecycle.discardRequests(
            committedSelectionState.pendingSourceSendRequests
        ) { _, _ in
            // Teardown cannot surface descriptor-close failures through a closed display.
        }
    }

    package func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        selectionEngine.recordCallbackError(error, context: context)
    }
}

struct PendingDragOfferMetadata {
    var sourceActions: DragActionSet = []
    var selectedAction: DragAction?
}
