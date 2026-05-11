extension DisplaySession {
    package func dragOfferOnOwnerThread(for seatID: SeatID) throws -> DataOfferSnapshot? {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.dragOffer(for: seatID)
    }

    package func dragOfferOnOwnerThread(id offerID: DataOfferID) throws -> DataOfferSnapshot {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.dragOffer(id: offerID)
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
}
