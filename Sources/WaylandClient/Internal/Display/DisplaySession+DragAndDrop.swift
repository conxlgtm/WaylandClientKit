import WaylandRaw

extension DisplaySession {
    package func dragOfferOnOwnerThread(for seatID: SeatID) throws -> DataOfferSnapshot? {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.dragOffer(for: seatID)
    }

    package func receiveDragOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.receiveDragOffer(id: offerID, mimeType: mimeType)
    }

    package func acceptDragOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType?
    ) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.acceptDragOffer(id: offerID, mimeType: mimeType)
    }

    package func setDragOfferActionsOnOwnerThread(
        id offerID: DataOfferID,
        actions: DragActionSet,
        preferredAction: DragAction
    ) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.setDragOfferActions(
            id: offerID,
            actions: actions,
            preferredAction: preferredAction
        )
    }

    package func finishDragOfferOnOwnerThread(id offerID: DataOfferID) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.finishDragOffer(id: offerID)
    }

    package func cancelDragOfferOnOwnerThread(id offerID: DataOfferID) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.cancelDragOffer(id: offerID)
    }

    package func startDragOnOwnerThread(
        _ configuration: DragSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial,
        origin: any DataTransferDragOriginBinding,
        icon: DragIcon
    ) throws -> DataSourceSnapshot {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.startDrag(
            DataTransferStartDragRequest(
                seatID: seatID,
                payloads: configuration.payloadSet,
                actions: configuration.actions,
                serial: serial,
                origin: origin,
                icon: icon
            )
        )
    }

    package func cancelDragSourceOnOwnerThread(id sourceID: DataSourceID) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.cancelDragSource(id: sourceID)
    }

    package func createToplevelDragOnOwnerThread(
        sourceID: DataSourceID,
        manager: RawXDGToplevelDragManager
    ) throws -> RawXDGToplevelDrag {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.createToplevelDrag(sourceID: sourceID, manager: manager)
    }
}
