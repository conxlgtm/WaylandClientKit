import Foundation
import WaylandRaw
import WaylandRuntime

final class SelectionEngine {
    let backend: any SelectionEngineBackend

    let kind: SelectionEngineKind
    let eventQueue: DataTransferEventQueue
    let hooks: SelectionEngineHooks
    var deviceBindings: [SeatID: any SelectionEngineDeviceBinding] = [:]
    var offerIDsByHandle: [SelectionEngineOfferHandle: DataOfferID] = [:]
    var offersByID: [DataOfferID: SelectionEngineOfferRecord] = [:]
    var selectionBySeat: [SeatID: DataSelectionState] = [:]
    var sourcesByID: [DataSourceID: SelectionEngineSourceRecord] = [:]
    var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    var detachedSourceSendIDs: Set<DataSourceID> = []
    var pendingCallbackFailures: FIFOQueue<DataTransferCallbackFailure> = []
    var offerIDs = IDGenerator<DataOfferID>()
    var sourceIDs = IDGenerator<DataSourceID>()
    var isShutdown = false

    init(
        kind selectionKind: SelectionEngineKind,
        backend selectionBackend: any SelectionEngineBackend,
        eventQueue dataTransferEventQueue: DataTransferEventQueue,
        hooks engineHooks: SelectionEngineHooks = SelectionEngineHooks()
    ) {
        selectionBackend.preconditionIsOwnerThread()
        kind = selectionKind
        backend = selectionBackend
        eventQueue = dataTransferEventQueue
        hooks = engineHooks
    }

    var boundSeatIDs: Set<SeatID> {
        Set(deviceBindings.keys)
    }

    var offerSnapshots: [DataOfferSnapshot] {
        offersByID.values
            .filter(\.isSelected)
            .sortedByRawValue(\.id)
            .map { $0.snapshot() }
    }

    var sourceSnapshots: [DataSourceSnapshot] {
        sourcesByID.values
            .map(\.snapshot)
            .sortedByRawValue(\.id)
    }

    var pendingCallbackError: DataTransferCallbackFailure? {
        pendingCallbackFailures.first
    }

    func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let desiredSeats = Set(seatIDs)
        let currentSeats = boundSeatIDs
        for seatID in currentSeats.subtracting(desiredSeats).sortedByRawValue() {
            removeSeat(seatID)
        }
        for seatID in desiredSeats.subtracting(currentSeats).sortedByRawValue() {
            try addSeat(seatID)
        }
    }

    func addSeat(_ seatID: SeatID) throws {
        backend.preconditionIsOwnerThread()
        guard !isShutdown, deviceBindings[seatID] == nil else { return }

        selectionBySeat[seatID] = DataSelectionState.none
        do {
            let binding = try backend.bindDevice(for: seatID) { [weak self] event in
                self?.handleDeviceEvent(event, seatID: seatID)
            }
            deviceBindings[seatID] = binding
        } catch {
            selectionBySeat[seatID] = nil
            throw error
        }
    }

    func removeSeat(_ seatID: SeatID) {
        backend.preconditionIsOwnerThread()
        guard let device = deviceBindings.removeValue(forKey: seatID) else { return }

        let selection = selectionBySeat.removeValue(forKey: seatID) ?? DataSelectionState.none
        var cleanup = removeSelection(selection, publishSourceCancellation: true)
        let remainingOfferIDs = offersByID.values
            .filter { $0.seatID == seatID }
            .map(\.id)
            .sortedByRawValue()
        for offerID in remainingOfferIDs {
            if let offer = removeOffer(offerID) {
                cleanup.offers.append(offer)
            }
        }
        let remainingSourceIDs = sourcesByID.values
            .filter { $0.snapshot.seatID == seatID }
            .map(\.snapshot.id)
            .sortedByRawValue()
        for sourceID in remainingSourceIDs {
            appendRemovedSource(
                sourceID,
                publishCancellation: true,
                to: &cleanup
            )
        }

        device.release()
        perform(cleanup)
    }

    func selectionState(for seatID: SeatID) -> DataSelectionState {
        selectionBySeat[seatID] ?? DataSelectionState.none
    }

    func deviceBindingForDrag(
        seatID: SeatID
    ) -> (any DataTransferDeviceBinding)? {
        deviceBindings[seatID]?.dragAndDropBinding
    }

    func offer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        _ = try requireDevice(for: seatID)

        guard case .remoteOffer(let offerID) = selectionState(for: seatID) else {
            return nil
        }
        guard let offer = offersByID[offerID], offer.isSelected else {
            throw kind.unknownOfferError(offerID)
        }
        return offer.snapshot()
    }

    func offerSnapshot(_ offerID: DataOfferID) -> DataOfferSnapshot? {
        guard let offer = offersByID[offerID], offer.isSelected else { return nil }
        return offer.snapshot()
    }

    func offerBinding(
        _ offerID: DataOfferID
    ) -> (any DataTransferOfferResourceBinding)? {
        offersByID[offerID]?.binding
    }

    func offerID(for handle: SelectionEngineOfferHandle) -> DataOfferID? {
        offerIDsByHandle[handle]
    }

    func containsOffer(_ offerID: DataOfferID) -> Bool {
        offersByID[offerID] != nil
    }

    func receiveOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard let offer = offersByID[offerID], offer.isSelected else {
            throw kind.unknownOfferError(offerID)
        }

        return try backend.receiveOffer(
            offer.snapshot(),
            using: offer.binding,
            mimeType: mimeType
        )
    }
}
