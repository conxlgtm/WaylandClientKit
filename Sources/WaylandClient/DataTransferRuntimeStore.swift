import Foundation
import WaylandRaw

typealias RuntimeDataOfferHandleIndexEntry = (
    handle: RawDataOfferHandle,
    offerID: DataOfferID
)

enum RuntimeDataOffer {
    case pending(
        handle: RawDataOfferHandle,
        binding: any DataTransferOfferBinding,
        seatID: SeatID,
        mimeTypes: [MIMEType]
    )
    case active(handle: RawDataOfferHandle, binding: any DataTransferOfferBinding)

    var handle: RawDataOfferHandle {
        switch self {
        case .pending(let handle, _, _, _), .active(let handle, _):
            handle
        }
    }

    var binding: any DataTransferOfferBinding {
        switch self {
        case .pending(_, let binding, _, _), .active(_, let binding):
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

    mutating func markActive() {
        self = .active(handle: handle, binding: binding)
    }
}

struct RuntimeDataSource {
    let binding: any DataTransferSourceBinding
    let payloads: DataTransferSourcePayloadSet
}

struct DataTransferRuntimeStore {
    private var deviceBindings: [SeatID: any DataTransferDeviceBinding] = [:]
    private var sourceRecords: [DataSourceID: RuntimeDataSource] = [:]
    private var pendingSourceSendRequests: [DataTransferSourceSendRequest] = []
    private var offerIDsByHandle: [RawDataOfferHandle: DataOfferID] = [:]
    private var runtimeOffersByID: [DataOfferID: RuntimeDataOffer] = [:]
    private var pendingCallbackFailure: DataTransferCallbackFailure?

    var boundSeatIDs: Set<SeatID> {
        Set(deviceBindings.keys)
    }

    var sourceIDs: Set<DataSourceID> {
        Set(sourceRecords.keys)
    }

    var offerIDs: Set<DataOfferID> {
        Set(runtimeOffersByID.keys)
    }

    var indexedOfferIDs: Set<DataOfferID> {
        Set(offerIDsByHandle.values)
    }

    var callbackFailure: DataTransferCallbackFailure? {
        pendingCallbackFailure
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
            handle: handle,
            binding: binding,
            seatID: seatID,
            mimeTypes: []
        )
    }

    mutating func appendPendingMIMEType(
        _ mimeType: MIMEType,
        offerID: DataOfferID
    ) throws {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOffer
        }

        runtimeOffer.appendPendingMIMEType(mimeType)
        runtimeOffersByID[offerID] = runtimeOffer
    }

    mutating func markOfferActive(_ offerID: DataOfferID) throws -> RuntimeDataOffer {
        guard var runtimeOffer = runtimeOffersByID[offerID] else {
            throw DataTransferError.unknownOffer
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
    }

    mutating func insertSource(
        binding: any DataTransferSourceBinding,
        payloads: DataTransferSourcePayloadSet,
        sourceID: DataSourceID
    ) {
        sourceRecords[sourceID] = RuntimeDataSource(
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
        sourceRecords.removeValue(forKey: sourceID)
    }

    mutating func appendSourceSendRequest(_ request: DataTransferSourceSendRequest) {
        pendingSourceSendRequests.append(request)
    }

    mutating func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        defer { pendingSourceSendRequests.removeAll(keepingCapacity: true) }
        return pendingSourceSendRequests
    }

    mutating func replaceSourceSendRequests(_ requests: [DataTransferSourceSendRequest]) {
        pendingSourceSendRequests = requests
    }

    func pendingSourceSendRequestsForInvariantChecks() -> [DataTransferSourceSendRequest] {
        pendingSourceSendRequests
    }

    mutating func takeCallbackFailure() -> DataTransferCallbackFailure? {
        defer { pendingCallbackFailure = nil }
        return pendingCallbackFailure
    }

    mutating func recordCallbackFailure(_ failure: DataTransferCallbackFailure) {
        guard pendingCallbackFailure == nil else {
            return
        }

        pendingCallbackFailure = failure
    }
}
