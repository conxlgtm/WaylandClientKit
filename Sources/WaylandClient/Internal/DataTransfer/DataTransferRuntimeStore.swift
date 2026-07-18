import Foundation
import WaylandRaw

typealias RuntimeDataOfferHandleIndexEntry = (
    handle: RawDataOfferHandle,
    offerID: DataOfferID
)

enum RuntimeDataOffer {
    case pending(PendingRuntimeDataOffer)
    case active(handle: RawDataOfferHandle, binding: any DataTransferOfferBinding)

    var handle: RawDataOfferHandle {
        switch self {
        case .pending(let offer):
            offer.handle
        case .active(let handle, _):
            handle
        }
    }

    var binding: any DataTransferOfferBinding {
        switch self {
        case .pending(let offer):
            offer.binding
        case .active(_, let binding):
            binding
        }
    }

    var pendingSeatID: SeatID? {
        guard case .pending(let offer) = self else {
            return nil
        }

        return offer.seatID
    }

    var pendingMIMETypes: [MIMEType] {
        guard case .pending(let offer) = self else {
            return []
        }

        return offer.mimeTypes
    }

    var pendingSourceActions: DragActionSet {
        guard case .pending(let offer) = self else {
            return []
        }

        return offer.sourceActions
    }

    var pendingSelectedAction: DragAction? {
        guard case .pending(let offer) = self else {
            return nil
        }

        return offer.selectedAction
    }

    mutating func appendPendingMIMEType(_ mimeType: MIMEType) {
        guard case .pending(var offer) = self else {
            return
        }
        guard !offer.mimeTypes.contains(mimeType) else {
            return
        }

        offer.mimeTypes.append(mimeType)
        self = .pending(offer)
    }

    mutating func setPendingSourceActions(_ actions: DragActionSet) {
        guard case .pending(var offer) = self else {
            return
        }

        offer.sourceActions = actions
        self = .pending(offer)
    }

    mutating func setPendingSelectedAction(_ action: DragAction) {
        guard case .pending(var offer) = self else {
            return
        }

        offer.selectedAction = action
        self = .pending(offer)
    }

    mutating func markActive() {
        self = .active(handle: handle, binding: binding)
    }
}

struct PendingRuntimeDataOffer {
    let handle: RawDataOfferHandle
    let binding: any DataTransferOfferBinding
    let seatID: SeatID
    var mimeTypes: [MIMEType]
    var sourceActions: DragActionSet
    var selectedAction: DragAction?
}

struct RuntimeDataSource {
    let id: DataSourceID
    let binding: any DataTransferSourceBinding
    let payloads: DataTransferSourcePayloadSet

    init(
        id sourceID: DataSourceID,
        binding sourceBinding: any DataTransferSourceBinding,
        payloads sourcePayloads: DataTransferSourcePayloadSet
    ) throws {
        try sourceBinding.validateID(sourceID)

        id = sourceID
        binding = sourceBinding
        payloads = sourcePayloads
    }
}

struct DataTransferStore {
    private var state = DataTransferState()
    private var sourceRecords: [DataSourceID: RuntimeDataSource] = [:]
    private var offerIDsByHandle: [RawDataOfferHandle: DataOfferID] = [:]
    private var runtimeOffersByID: [DataOfferID: RuntimeDataOffer] = [:]

    var sourceIDs: Set<DataSourceID> {
        Set(sourceRecords.keys)
    }

    var sourcesByIDForInvariantChecks: [DataSourceID: RuntimeDataSource] {
        sourceRecords
    }

    var offerIDs: Set<DataOfferID> {
        Set(runtimeOffersByID.keys)
    }

    var indexedOfferIDs: Set<DataOfferID> {
        Set(offerIDsByHandle.values)
    }

    var seatSnapshots: [DataTransferSeatSnapshot] {
        state.seatSnapshots
    }

    var offerSnapshots: [DataOfferSnapshot] {
        state.offerSnapshots
    }

    var sourceSnapshots: [DataSourceSnapshot] {
        state.sourceSnapshots
    }

    func seatSnapshot(_ seatID: SeatID) -> DataTransferSeatSnapshot? {
        state.seatSnapshot(seatID)
    }

    func offerSnapshot(_ offerID: DataOfferID) -> DataOfferSnapshot? {
        state.offerSnapshot(offerID)
    }

    func sourceSnapshot(_ sourceID: DataSourceID) -> DataSourceSnapshot? {
        state.sourceSnapshot(sourceID)
    }

    func transitionPlan(for actions: [DataTransferAction]) throws -> DataTransferTransitionPlan {
        try state.reduce(actions)
    }

    mutating func replaceState(_ nextState: DataTransferState) {
        state = nextState
    }

    var offersByIDForInvariantChecks: [DataOfferID: RuntimeDataOffer] {
        runtimeOffersByID
    }

    var offerHandleIndexEntries: [RuntimeDataOfferHandleIndexEntry] {
        offerIDsByHandle.map { (handle: $0.key, offerID: $0.value) }
    }

    func hasOffer(handle: RawDataOfferHandle) -> Bool {
        offerIDsByHandle[handle] != nil
    }

    func offerID(for handle: RawDataOfferHandle) -> DataOfferID? {
        offerIDsByHandle[handle]
    }

    func runtimeOffer(_ offerID: DataOfferID) -> RuntimeDataOffer? {
        runtimeOffersByID[offerID]
    }

    func offerHandleMatchesIndex(handle: RawDataOfferHandle, offerID: DataOfferID) -> Bool {
        runtimeOffersByID[offerID]?.handle == handle
    }

    mutating func insertPendingOffer(
        handle: RawDataOfferHandle,
        offerID: DataOfferID,
        binding: any DataTransferOfferBinding,
        seatID: SeatID
    ) {
        offerIDsByHandle[handle] = offerID
        runtimeOffersByID[offerID] = .pending(
            PendingRuntimeDataOffer(
                handle: handle,
                binding: binding,
                seatID: seatID,
                mimeTypes: [],
                sourceActions: [],
                selectedAction: nil
            )
        )
    }

    mutating func appendPendingMIMEType(
        _ mimeType: MIMEType,
        offerID: DataOfferID
    ) throws {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
        }

        runtimeOffer.appendPendingMIMEType(mimeType)
        runtimeOffersByID[offerID] = runtimeOffer
    }

    mutating func setPendingSourceActions(
        _ actions: DragActionSet,
        offerID: DataOfferID
    ) throws {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
        }

        runtimeOffer.setPendingSourceActions(actions)
        runtimeOffersByID[offerID] = runtimeOffer
    }

    mutating func setPendingSelectedAction(
        _ action: DragAction,
        offerID: DataOfferID
    ) throws {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
        }

        runtimeOffer.setPendingSelectedAction(action)
        runtimeOffersByID[offerID] = runtimeOffer
    }

    @discardableResult
    mutating func removeOffer(_ offerID: DataOfferID) -> RuntimeDataOffer? {
        guard let runtimeOffer = runtimeOffersByID.removeValue(forKey: offerID) else {
            return nil
        }

        offerIDsByHandle[runtimeOffer.handle] = nil
        return runtimeOffer
    }

    func pendingOfferIDs(for seatID: SeatID) -> [DataOfferID] {
        runtimeOffersByID
            .filter { _, runtimeOffer in runtimeOffer.pendingSeatID == seatID }
            .map(\.key)
            .sortedByRawValue()
    }

    mutating func insertSource(_ source: RuntimeDataSource) {
        precondition(sourceRecords[source.id] == nil, "data source was inserted twice")
        sourceRecords[source.id] = source
    }

    mutating func activateOfferForCommit(_ offerID: DataOfferID) {
        guard var offer = runtimeOffersByID[offerID] else {
            preconditionFailure("activated data offer is missing its runtime record")
        }
        guard case .pending = offer else {
            preconditionFailure("data offer was activated twice")
        }

        offer.markActive()
        runtimeOffersByID[offerID] = offer
    }

    func sourcePayloadData(sourceID: DataSourceID, mimeType: MIMEType) -> Data? {
        sourceRecords[sourceID]?.payloads.data(for: mimeType)
    }

    @discardableResult
    mutating func removeSource(_ sourceID: DataSourceID) -> RuntimeDataSource? {
        return sourceRecords.removeValue(forKey: sourceID)
    }
}
