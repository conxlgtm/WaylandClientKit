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
