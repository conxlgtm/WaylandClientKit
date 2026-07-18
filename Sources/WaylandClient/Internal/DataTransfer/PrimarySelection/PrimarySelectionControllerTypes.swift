import WaylandRaw

package protocol PrimarySelectionDeviceBinding: AnyObject {
    func setSelection(
        source: (any DataTransferSourceResourceBinding)?,
        serial: InputSerial
    )
    func release()
}

package protocol PrimarySelectionControllerBackend: AnyObject, DataTransferOfferReceiveBackend {
    func preconditionIsOwnerThread()
    func bindPrimarySelectionDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) throws -> any PrimarySelectionDeviceBinding
    func adoptPrimarySelectionOffer(
        handle: RawPrimarySelectionOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) throws -> any DataTransferOfferResourceBinding
    func createPrimarySelectionSource(
        id: DataSourceID,
        onEvent: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) throws -> any DataTransferSourceResourceBinding
    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor

    var sourceDescriptorIO: DataTransferSourceDescriptorIO { get }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult
}

struct RuntimePrimarySelectionOffer {
    let handle: RawPrimarySelectionOfferHandle
    let binding: any DataTransferOfferResourceBinding
    private var state: DataTransferOfferState
    private var isActive = false

    init(
        handle offerHandle: RawPrimarySelectionOfferHandle,
        binding offerBinding: any DataTransferOfferResourceBinding,
        id offerID: DataOfferID,
        seatID: SeatID
    ) {
        handle = offerHandle
        binding = offerBinding
        state = DataTransferOfferState(
            id: offerID,
            role: .selection(seatID: seatID)
        )
    }

    var pendingSeatID: SeatID? {
        isActive ? nil : state.role.seatID
    }

    var pendingMIMETypes: [MIMEType] {
        isActive ? [] : state.mimeTypes
    }

    var snapshot: DataOfferSnapshot? {
        isActive ? state.snapshot : nil
    }

    mutating func appendMIMETypeIfNew(_ mimeType: MIMEType) throws -> Bool {
        try state.appendMIMETypeIfNew(mimeType)
    }

    mutating func markActive() {
        isActive = true
    }
}

struct RuntimePrimarySelectionSource {
    let binding: any DataTransferSourceResourceBinding
    let payloads: DataTransferSourcePayloadSet
    private let state: DataTransferSourceState

    var snapshot: DataSourceSnapshot {
        state.snapshot
    }

    init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        binding sourceBinding: any DataTransferSourceResourceBinding,
        payloads sourcePayloads: DataTransferSourcePayloadSet
    ) throws {
        try sourceBinding.validateID(sourceID)

        binding = sourceBinding
        payloads = sourcePayloads
        state = try DataTransferSourceState(
            id: sourceID,
            role: .selection(seatID: sourceSeatID),
            mimeTypes: sourcePayloads.mimeTypes
        )
    }
}
