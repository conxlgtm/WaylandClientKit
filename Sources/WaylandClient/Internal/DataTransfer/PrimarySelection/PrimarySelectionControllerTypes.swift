import WaylandRaw

package protocol PrimarySelectionDeviceBinding: AnyObject {
    var seatID: SeatID { get }

    func setSelection(source: (any PrimarySelectionSourceBinding)?, serial: InputSerial)
    func release()
}

package protocol PrimarySelectionOfferBinding: AnyObject {
    var id: DataOfferID { get }

    func receive(mimeType: MIMEType, fd: Int32)
    func destroy()
}

package protocol PrimarySelectionSourceBinding: AnyObject {
    var id: DataSourceID { get }

    func offer(mimeType: MIMEType)
    func destroy()
}

package protocol PrimarySelectionControllerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func bindPrimarySelectionDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) throws -> any PrimarySelectionDeviceBinding
    func adoptPrimarySelectionOffer(
        handle: RawPrimarySelectionOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) throws -> any PrimarySelectionOfferBinding
    func createPrimarySelectionSource(
        id: DataSourceID,
        onEvent: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) throws -> any PrimarySelectionSourceBinding
    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

enum RuntimePrimarySelectionOffer {
    case pending(
        handle: RawPrimarySelectionOfferHandle,
        binding: any PrimarySelectionOfferBinding,
        seatID: SeatID,
        mimeTypes: [MIMEType]
    )
    case active(
        handle: RawPrimarySelectionOfferHandle,
        binding: any PrimarySelectionOfferBinding,
        snapshot: DataOfferSnapshot
    )

    var handle: RawPrimarySelectionOfferHandle {
        switch self {
        case .pending(let handle, _, _, _), .active(let handle, _, _):
            handle
        }
    }

    var binding: any PrimarySelectionOfferBinding {
        switch self {
        case .pending(_, let binding, _, _), .active(_, let binding, _):
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

    var snapshot: DataOfferSnapshot? {
        guard case .active(_, _, let snapshot) = self else {
            return nil
        }

        return snapshot
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

    mutating func markActive(id offerID: DataOfferID) throws {
        guard case .pending(let handle, let binding, let seatID, let mimeTypes) = self else {
            return
        }

        self = .active(
            handle: handle,
            binding: binding,
            snapshot: try DataOfferSnapshot(
                id: offerID,
                role: .selection(seatID: seatID),
                mimeTypes: mimeTypes
            )
        )
    }
}

struct RuntimePrimarySelectionSource {
    let id: DataSourceID
    let binding: any PrimarySelectionSourceBinding
    let payloads: DataTransferSourcePayloadSet
    let snapshot: DataSourceSnapshot

    init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        binding sourceBinding: any PrimarySelectionSourceBinding,
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
        snapshot = try DataSourceSnapshot(
            id: sourceID,
            seatID: sourceSeatID,
            mimeTypes: sourcePayloads.mimeTypes
        )
    }
}

enum PrimarySelectionSelectionState: Equatable {
    case none
    case remoteOffer(DataOfferID)
    case ownedSource(DataSourceID)
}
