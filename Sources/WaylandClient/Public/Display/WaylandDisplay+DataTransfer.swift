extension WaylandDisplay {
    public func clipboardOffer(for seatID: SeatID) throws -> ClipboardOffer? {
        try requireCore().clipboardOffer(for: seatID).map { offer in
            ClipboardOffer(snapshot: offer, display: self)
        }
    }

    /// Requests ownership of the regular clipboard selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary. This call creates and installs
    /// the local data source request but cannot prove compositor acceptance synchronously.
    public func requestClipboardSelection(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> ClipboardSource {
        let source = try requireCore().setClipboard(
            configuration,
            seatID: seatID,
            serial: serial
        )
        return ClipboardSource(snapshot: source, display: self)
    }

    /// Requests clearing the regular clipboard selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClearClipboard(seatID: SeatID, serial: InputSerial) throws {
        try requireCore().clearClipboard(seatID: seatID, serial: serial)
    }

    package func requestClearClipboard(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try requireCore().clearClipboard(
            sourceID: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func receiveClipboardOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try requireCore().receiveClipboardOffer(id: offerID, mimeType: mimeType)
    }
}

extension WaylandDisplay {
    public func primarySelectionOffer(for seatID: SeatID) throws -> PrimarySelectionOffer? {
        try requireCore().primarySelectionOffer(for: seatID).map { offer in
            PrimarySelectionOffer(snapshot: offer, display: self)
        }
    }

    /// Requests ownership of the primary selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary. Primary selection is usually
    /// tied to selected text and focus, so compositor acceptance is asynchronous.
    public func requestPrimarySelection(
        _ configuration: PrimarySelectionSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> PrimarySelectionSource {
        let source = try requireCore().setPrimarySelection(
            configuration,
            seatID: seatID,
            serial: serial
        )
        return PrimarySelectionSource(snapshot: source, display: self)
    }

    /// Requests clearing the primary selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClearPrimarySelection(seatID: SeatID, serial: InputSerial) throws {
        try requireCore().clearPrimarySelection(seatID: seatID, serial: serial)
    }

    package func requestClearPrimarySelection(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try requireCore().clearPrimarySelection(
            sourceID: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func receivePrimarySelectionOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try requireCore().receivePrimarySelectionOffer(id: offerID, mimeType: mimeType)
    }
}
