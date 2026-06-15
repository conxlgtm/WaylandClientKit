extension WaylandDisplay {
    public func clipboardOffer(for seatID: SeatID) throws -> ClipboardOffer? {
        try requireCore().clipboardOffer(for: seatID).map { offer in
            ClipboardOffer(snapshot: offer, display: self)
        }
    }

    public func dragOffer(for seatID: SeatID) throws -> DragOffer? {
        try requireCore().dragOffer(for: seatID).map { offer in
            DragOffer(snapshot: offer, display: self)
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

    package func startDrag(
        from windowID: WindowID,
        source configuration: DragSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial,
        icon: DragIcon
    ) throws -> DragSource {
        let source = try requireCore().startDrag(
            from: windowID,
            source: configuration,
            seatID: seatID,
            serial: serial,
            icon: icon
        )
        return DragSource(snapshot: source, display: self)
    }

    package func cancelDragSource(id sourceID: DataSourceID) throws {
        try requireCore().cancelDragSource(id: sourceID)
    }

    package func attachToToplevelDrag(
        window: Window,
        source: DragSource,
        seatID: SeatID,
        serial: InputSerial,
        offset: LogicalOffset
    ) throws -> ToplevelDrag {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }
        guard source.isOwned(by: self) else {
            throw ClientError.display(.foreignDragSource(source.id))
        }
        guard source.seatID == seatID else {
            throw ClientError.display(
                .dragSourceSeatMismatch(source.id, expected: seatID, actual: source.seatID)
            )
        }

        let dragID = try requireCore().createToplevelDrag(
            windowID: window.id,
            sourceID: source.sourceID,
            sourceIdentity: source.id,
            seatID: seatID,
            serial: serial,
            offset: offset
        )
        return ToplevelDrag(
            id: dragID,
            windowID: window.id,
            source: source.id,
            seatID: seatID,
            serial: serial,
            display: self
        )
    }

    package func destroyToplevelDrag(_ dragID: ToplevelDragID) throws {
        try requireCore().destroyToplevelDrag(dragID)
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

    package func receiveDragOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try requireCore().receiveDragOffer(id: offerID, mimeType: mimeType)
    }

    package func acceptDragOffer(id offerID: DataOfferID, mimeType: MIMEType?) throws {
        try requireCore().acceptDragOffer(id: offerID, mimeType: mimeType)
    }

    package func setDragOfferActions(
        id offerID: DataOfferID,
        actions: DragActionSet,
        preferredAction: DragAction
    ) throws {
        try requireCore().setDragOfferActions(
            id: offerID,
            actions: actions,
            preferredAction: preferredAction
        )
    }

    package func finishDragOffer(id offerID: DataOfferID) throws {
        try requireCore().finishDragOffer(id: offerID)
    }

    package func cancelDragOffer(id offerID: DataOfferID) throws {
        try requireCore().cancelDragOffer(id: offerID)
    }
}

extension WaylandDisplay {
    public func primarySelectionOffer(for seatID: SeatID) throws -> PrimarySelectionOffer? {
        try requirePrimarySelectionHandler().primarySelectionOffer(for: seatID).map { offer in
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
        let source = try requirePrimarySelectionHandler().setPrimarySelection(
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
        try requirePrimarySelectionHandler().clearPrimarySelection(
            seatID: seatID,
            serial: serial
        )
    }

    package func requestClearPrimarySelection(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try requirePrimarySelectionHandler().clearPrimarySelection(
            sourceID: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func receivePrimarySelectionOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try requirePrimarySelectionHandler().receivePrimarySelectionOffer(
            id: offerID,
            mimeType: mimeType
        )
    }
}
