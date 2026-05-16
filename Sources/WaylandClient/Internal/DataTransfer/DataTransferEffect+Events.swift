extension DataTransferEffect {
    package var publishedEvent: DataTransferEvent? {
        switch self {
        case .publishSelectionChanged(let seatID, let offerID):
            .clipboardSelectionChanged(
                ClipboardSelectionEvent(seatID: seatID, offerID: offerID)
            )
        case .publishSourceCancelled(let sourceID):
            .clipboardSourceCancelled(sourceID.clipboardIdentity)
        case .publishDragEntered(let enter):
            .dragEntered(
                DragEnterEvent(
                    seatID: enter.seatID,
                    offerID: enter.offerID,
                    serial: enter.serial,
                    location: enter.location,
                    target: enter.target
                )
            )
        case .publishDragMotion(let seatID, let offerID, let time, let location):
            .dragMotion(
                DragMotionEvent(
                    seatID: seatID,
                    offerID: offerID,
                    time: time,
                    location: location
                )
            )
        case .publishDragLeft(let seatID, let offerID):
            .dragLeft(DragLeaveEvent(seatID: seatID, offerID: offerID))
        case .publishDragDropped(let seatID, let offerID):
            .dragDropped(DragDropEvent(seatID: seatID, offerID: offerID))
        case .publishDragOfferChanged(let seatID, let offerID):
            .dragOfferChanged(
                DragOfferChangedEvent(seatID: seatID, offerID: offerID)
            )
        case .publishDragSourceCancelled(let sourceID):
            .dragSourceCancelled(sourceID.dragIdentity)
        case .publishDragSourceTargetChanged(let sourceID, let mimeType):
            .dragSourceTargetChanged(
                DragSourceTargetEvent(sourceID: sourceID, mimeType: mimeType)
            )
        case .publishDragSourceActionChanged(let sourceID, let action):
            .dragSourceActionChanged(
                DragSourceActionEvent(sourceID: sourceID, action: action)
            )
        case .publishDragSourceDropPerformed(let sourceID):
            .dragSourceDropPerformed(sourceID.dragIdentity)
        case .publishDragSourceFinished(let sourceID, let finalAction):
            .dragSourceFinished(
                DragSourceFinishedEvent(
                    sourceID: sourceID,
                    finalAction: finalAction
                )
            )
        case .bindDataDevice, .releaseDataDevice, .destroyOffer,
            .destroySource, .cancelSource:
            nil
        }
    }
}
