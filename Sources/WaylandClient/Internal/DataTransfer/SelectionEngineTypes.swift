import Foundation
import WaylandRaw
import WaylandRuntime

enum SelectionEngineKind: Sendable {
    case clipboard
    case primarySelection

    func missingDeviceError(_ seatID: SeatID) -> DataTransferError {
        switch self {
        case .clipboard:
            .missingDataDevice(seatID)
        case .primarySelection:
            .missingPrimarySelectionDevice(seatID)
        }
    }

    func duplicateOfferError(
        handle: SelectionEngineOfferHandle,
        existingOfferID: DataOfferID?
    ) -> DataTransferError {
        switch self {
        case .clipboard:
            .duplicateOfferHandle(
                rawValue: handle.rawValue,
                existingOffer: existingOfferID.map(ClipboardOfferIdentity.init)
            )
        case .primarySelection:
            .duplicatePrimarySelectionOfferHandle(
                rawValue: handle.rawValue,
                existingOffer: existingOfferID.map(PrimarySelectionOfferIdentity.init)
            )
        }
    }

    func unknownOfferError(_ offerID: DataOfferID) -> DataTransferError {
        switch self {
        case .clipboard:
            .unknownOfferIdentity(offerID.clipboardIdentity)
        case .primarySelection:
            .unknownPrimarySelectionOfferIdentity(offerID.primarySelectionIdentity)
        }
    }

    func unknownSourceError(_ sourceID: DataSourceID) -> DataTransferError {
        switch self {
        case .clipboard:
            .unknownSourceIdentity(sourceID.clipboardIdentity)
        case .primarySelection:
            .unknownPrimarySelectionSourceIdentity(sourceID.primarySelectionIdentity)
        }
    }

    func offerIdentity(_ offerID: DataOfferID) -> DataTransferOfferIdentity {
        switch self {
        case .clipboard:
            .clipboard(offerID.clipboardIdentity)
        case .primarySelection:
            .primarySelection(offerID.primarySelectionIdentity)
        }
    }

    func deviceCallbackContext(_ seatID: SeatID) -> DataTransferCallbackContext {
        switch self {
        case .clipboard:
            .dataDevice(seatID)
        case .primarySelection:
            .primarySelectionDevice(seatID)
        }
    }

    func offerCallbackContext(_ offerID: DataOfferID) -> DataTransferCallbackContext {
        switch self {
        case .clipboard:
            .dataOffer(offerID.clipboardIdentity)
        case .primarySelection:
            .primarySelectionOffer(offerID.primarySelectionIdentity)
        }
    }

    func sourceCallbackContext(_ sourceID: DataSourceID) -> DataTransferCallbackContext {
        switch self {
        case .clipboard:
            .dataSource(sourceID.clipboardIdentity)
        case .primarySelection:
            .primarySelectionSource(sourceID.primarySelectionIdentity)
        }
    }

    func selectionChangedEvent(
        seatID: SeatID,
        offerID: DataOfferID?
    ) -> DataTransferEvent {
        switch self {
        case .clipboard:
            .clipboardSelectionChanged(
                ClipboardSelectionEvent(seatID: seatID, offerID: offerID)
            )
        case .primarySelection:
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: offerID)
            )
        }
    }

    func sourceCancelledEvent(_ sourceID: DataSourceID) -> DataTransferEvent {
        switch self {
        case .clipboard:
            .clipboardSourceCancelled(sourceID.clipboardIdentity)
        case .primarySelection:
            .primarySelectionSourceCancelled(sourceID.primarySelectionIdentity)
        }
    }

    func writeSource(_ sourceID: DataSourceID) -> DataTransferSourceWriteSource {
        switch self {
        case .clipboard:
            .clipboard(sourceID)
        case .primarySelection:
            .primarySelection(sourceID)
        }
    }

    func sourceSendMIMEType(_ rawMIMEType: String?) throws -> MIMEType? {
        switch self {
        case .clipboard:
            guard let rawMIMEType, !rawMIMEType.isEmpty else { return nil }
            return try MIMEType(rawMIMEType)
        case .primarySelection:
            return try MIMEType(rawMIMEType ?? "")
        }
    }

    func discardedSendContext(
        _ request: DataTransferSourceSendRequest
    ) -> DataTransferCallbackContext {
        switch self {
        case .clipboard:
            .sourceWrite(request.source.diagnosticSource)
        case .primarySelection:
            .primarySelectionSource(request.sourceID.primarySelectionIdentity)
        }
    }
}

enum SelectionEngineOfferHandle: Hashable, Sendable {
    case clipboard(RawDataOfferHandle)
    case primarySelection(RawPrimarySelectionOfferHandle)

    var rawValue: UInt {
        switch self {
        case .clipboard(let handle):
            handle.rawValue
        case .primarySelection(let handle):
            handle.rawValue
        }
    }
}

enum SelectionEngineDeviceEvent: Sendable {
    case dataOffer(SelectionEngineOfferHandle?)
    case selection(SelectionEngineOfferHandle?)
}

enum SelectionEngineOfferEvent: Sendable {
    case mimeType(String?)
}

enum SelectionEngineSourceEvent: Sendable {
    case send(mimeType: String?, descriptor: Int32)
    case cancelled
    case target
    case invalidDragAndDropEvent(DataSourceCallbackEventKind)
}

protocol SelectionEngineDeviceBinding: AnyObject {
    var dragAndDropBinding: (any DataTransferDeviceBinding)? { get }

    func setSelection(
        source: (any DataTransferSourceResourceBinding)?,
        serial: InputSerial
    )
    func release()
}

protocol SelectionEngineBackend: AnyObject, DataTransferOfferReceiveBackend {
    func preconditionIsOwnerThread()
    func bindDevice(
        for seatID: SeatID,
        onEvent: @escaping (SelectionEngineDeviceEvent) -> Void
    ) throws -> any SelectionEngineDeviceBinding
    func adoptOffer(
        handle: SelectionEngineOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (SelectionEngineOfferEvent) -> Void
    ) throws -> any DataTransferOfferResourceBinding
    func createSource(
        id: DataSourceID,
        onEvent: @escaping (SelectionEngineSourceEvent) -> Void
    ) throws -> any DataTransferSourceResourceBinding

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }
}

struct SelectionEngineHooks {
    var sourceWillCancel: (DataSourceID) -> Void = { _ in () }
    var offerDidDestroy: (DataOfferID) -> Void = { _ in () }
    var unownedOfferEvent: (SelectionEngineOfferEvent, DataOfferID) -> Bool = { _, _ in false }
    var externalOfferID: (SelectionEngineOfferHandle) -> DataOfferID? = { _ in nil }
    var externalSourceIDs: () -> Set<DataSourceID> = { [] }
}

struct SelectionEngineClaimedOffer {
    let handle: SelectionEngineOfferHandle
    let id: DataOfferID
    let seatID: SeatID
    let mimeTypes: [MIMEType]
    let binding: any DataTransferOfferResourceBinding
}

struct SelectionEngineOfferRecord {
    let handle: SelectionEngineOfferHandle
    let id: DataOfferID
    let seatID: SeatID
    let binding: any DataTransferOfferResourceBinding
    var mimeTypes: [MIMEType] = []
    var isSelected = false

    mutating func appendMIMETypeIfNew(_ mimeType: MIMEType) -> Bool {
        guard !mimeTypes.contains(mimeType) else { return false }

        mimeTypes.append(mimeType)
        return true
    }

    func snapshot() -> DataOfferSnapshot {
        do {
            return try DataOfferSnapshot(
                id: id,
                role: .selection(seatID: seatID),
                mimeTypes: mimeTypes
            )
        } catch {
            preconditionFailure("invalid canonical selection offer \(id): \(error)")
        }
    }
}

struct SelectionEngineSourceRecord {
    let binding: any DataTransferSourceResourceBinding
    let payloads: DataTransferSourcePayloadSet
    let snapshot: DataSourceSnapshot

    init(
        id sourceID: DataSourceID,
        seatID: SeatID,
        binding sourceBinding: any DataTransferSourceResourceBinding,
        payloads sourcePayloads: DataTransferSourcePayloadSet
    ) throws {
        try sourceBinding.validateID(sourceID)
        binding = sourceBinding
        payloads = sourcePayloads
        snapshot = try DataSourceSnapshot(
            id: sourceID,
            seatID: seatID,
            mimeTypes: sourcePayloads.mimeTypes
        )
    }
}

struct SelectionEngineCleanup {
    var offers: [SelectionEngineOfferRecord] = []
    var sources: [SelectionEngineCleanupSource] = []
    var requests: [DataTransferSourceSendRequest] = []
}

struct SelectionEngineCleanupSource {
    let id: DataSourceID
    let record: SelectionEngineSourceRecord
    let publishesCancellation: Bool
}

struct CommittedSelectionEngineOffer {
    let id: DataOfferID
    let binding: any DataTransferOfferResourceBinding
}

struct CommittedSelectionEngineShutdown {
    let sources: [any DataTransferSourceResourceBinding]
    let offers: [CommittedSelectionEngineOffer]
    let devices: [any SelectionEngineDeviceBinding]
    let pendingSourceSendRequests: [DataTransferSourceSendRequest]
}
