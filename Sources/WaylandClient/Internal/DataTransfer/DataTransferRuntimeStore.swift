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
        guard sourceBinding.id == sourceID else {
            throw DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                expected: sourceID,
                actual: sourceBinding.id
            )
        }

        id = sourceID
        binding = sourceBinding
        payloads = sourcePayloads
    }
}

struct DataTransferStore {
    private var state = DataTransferState()
    private var deviceBindings: [SeatID: any DataTransferDeviceBinding] = [:]
    private var sourceRecords: [DataSourceID: RuntimeDataSource] = [:]
    private var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    private var detachedSourceSendIDs: Set<DataSourceID> = []
    private var offerIDsByHandle: [RawDataOfferHandle: DataOfferID] = [:]
    private var runtimeOffersByID: [DataOfferID: RuntimeDataOffer] = [:]
    private var pendingCallbackFailures: [DataTransferCallbackFailure] = []

    var boundSeatIDs: Set<SeatID> {
        Set(deviceBindings.keys)
    }

    var sourceIDs: Set<DataSourceID> {
        Set(sourceRecords.keys)
    }

    var sourcesByIDForInvariantChecks: [DataSourceID: RuntimeDataSource] {
        sourceRecords
    }

    var detachedSourceSendIDsForInvariantChecks: Set<DataSourceID> {
        detachedSourceSendIDs
    }

    var offerIDs: Set<DataOfferID> {
        Set(runtimeOffersByID.keys)
    }

    var indexedOfferIDs: Set<DataOfferID> {
        Set(offerIDsByHandle.values)
    }

    var callbackFailure: DataTransferCallbackFailure? {
        pendingCallbackFailures.first
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

    func transitionPlan(for action: DataTransferAction) throws -> DataTransferTransitionPlan {
        try state.reduce(action)
    }

    mutating func replaceState(_ nextState: DataTransferState) {
        state = nextState
    }

    var offerBindingsByID: [DataOfferID: any DataTransferOfferBinding] {
        var bindings: [DataOfferID: any DataTransferOfferBinding] = [:]
        for (offerID, runtimeOffer) in runtimeOffersByID {
            bindings[offerID] = runtimeOffer.binding
        }
        return bindings
    }

    var offersByIDForInvariantChecks: [DataOfferID: RuntimeDataOffer] {
        runtimeOffersByID
    }

    var offerHandleIndexEntries: [RuntimeDataOfferHandleIndexEntry] {
        offerIDsByHandle.map { (handle: $0.key, offerID: $0.value) }
    }

    mutating func insertDeviceBinding(
        _ binding: any DataTransferDeviceBinding,
        for seatID: SeatID
    ) {
        deviceBindings[seatID] = binding
    }

    func deviceBinding(for seatID: SeatID) -> (any DataTransferDeviceBinding)? {
        deviceBindings[seatID]
    }

    @discardableResult
    mutating func removeDeviceBinding(
        for seatID: SeatID
    ) -> (any DataTransferDeviceBinding)? {
        deviceBindings.removeValue(forKey: seatID)
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

    mutating func markOfferActive(_ offerID: DataOfferID) throws -> RuntimeDataOffer {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOfferIdentity(offerID.clipboardIdentity)
        }

        runtimeOffer.markActive()
        runtimeOffersByID[offerID] = runtimeOffer
        return runtimeOffer
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

    mutating func insertSource(
        binding: any DataTransferSourceBinding,
        payloads: DataTransferSourcePayloadSet,
        sourceID: DataSourceID
    ) throws {
        sourceRecords[sourceID] = try RuntimeDataSource(
            id: sourceID,
            binding: binding,
            payloads: payloads
        )
    }

    func sourceBinding(for sourceID: DataSourceID) -> (any DataTransferSourceBinding)? {
        sourceRecords[sourceID]?.binding
    }

    func sourcePayloadData(sourceID: DataSourceID, mimeType: MIMEType) -> Data? {
        sourceRecords[sourceID]?.payloads.data(for: mimeType)
    }

    @discardableResult
    mutating func removeSource(_ sourceID: DataSourceID) -> RuntimeDataSource? {
        detachedSourceSendIDs.remove(sourceID)
        return sourceRecords.removeValue(forKey: sourceID)
    }

    @discardableResult
    mutating func detachSourcePreservingPendingSends(
        _ sourceID: DataSourceID
    ) -> RuntimeDataSource? {
        let source = sourceRecords.removeValue(forKey: sourceID)
        if pendingSourceSendRequests.contains(where: { $0.source.sourceID == sourceID }) {
            detachedSourceSendIDs.insert(sourceID)
        }
        return source
    }

    mutating func appendSourceSendRequest(_ request: DataTransferSourceSendRequest) {
        pendingSourceSendRequests.append(request)
    }

    mutating func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        let requests = pendingSourceSendRequests.drain()
        detachedSourceSendIDs.removeAll(keepingCapacity: true)
        return requests
    }

    mutating func removeSourceSendRequests(
        for sourceID: DataSourceID
    ) -> [DataTransferSourceSendRequest] {
        let removedRequests = pendingSourceSendRequests.removeAllReturning {
            $0.source.sourceID == sourceID
        }
        pruneDetachedSourceSendIDs()
        return removedRequests
    }

    mutating func replaceSourceSendRequests(_ requests: [DataTransferSourceSendRequest]) {
        pendingSourceSendRequests = requests
        pruneDetachedSourceSendIDs()
    }

    func pendingSourceSendRequestsForInvariantChecks() -> [DataTransferSourceSendRequest] {
        pendingSourceSendRequests
    }

    mutating func takeCallbackFailure() -> DataTransferCallbackFailure? {
        guard !pendingCallbackFailures.isEmpty else {
            return nil
        }

        return pendingCallbackFailures.removeFirst()
    }

    mutating func discardCallbackFailures() {
        pendingCallbackFailures.removeAll(keepingCapacity: false)
    }

    mutating func recordCallbackFailure(_ failure: DataTransferCallbackFailure) {
        pendingCallbackFailures.append(failure)
    }

    private mutating func pruneDetachedSourceSendIDs() {
        let pendingSourceIDs = Set(pendingSourceSendRequests.map(\.source.sourceID))
        detachedSourceSendIDs = detachedSourceSendIDs.intersection(pendingSourceIDs)
    }
}
