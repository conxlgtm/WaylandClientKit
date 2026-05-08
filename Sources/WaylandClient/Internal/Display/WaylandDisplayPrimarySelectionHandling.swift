protocol WaylandDisplayPrimarySelectionHandling {
    func primarySelectionOffer(for seatID: SeatID) throws -> DataOfferSnapshot?

    func receivePrimarySelectionOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor

    func setPrimarySelection(
        _ configuration: PrimarySelectionSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot

    func clearPrimarySelection(seatID: SeatID, serial: InputSerial) throws

    func clearPrimarySelection(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws
}

extension DisplayCore: WaylandDisplayPrimarySelectionHandling {}
