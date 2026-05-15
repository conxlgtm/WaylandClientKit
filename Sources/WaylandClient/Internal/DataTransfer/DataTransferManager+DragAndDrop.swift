import WaylandRaw

extension DataTransferManager {
    static func defaultTarget(for surfaceID: RawObjectID?) -> InputEventTarget {
        surfaceID == nil ? .focusless : .unmanagedSurface
    }

    func appendDragAndDropEvent(for effect: DataTransferEffect) {
        switch effect {
        case .publishDragEntered(let enter):
            eventQueue.append(
                .dragEntered(
                    DragEnterEvent(
                        seatID: enter.seatID,
                        offerID: enter.offerID,
                        serial: enter.serial,
                        location: enter.location,
                        target: enter.target
                    )
                )
            )
        case .publishDragMotion(let seatID, let offerID, let time, let location):
            eventQueue.append(
                .dragMotion(
                    DragMotionEvent(
                        seatID: seatID,
                        offerID: offerID,
                        time: time,
                        location: location
                    )
                )
            )
        case .publishDragLeft(let seatID, let offerID):
            eventQueue.append(
                .dragLeft(DragLeaveEvent(seatID: seatID, offerID: offerID))
            )
        case .publishDragDropped(let seatID, let offerID):
            eventQueue.append(
                .dragDropped(DragDropEvent(seatID: seatID, offerID: offerID))
            )
        case .publishDragOfferChanged(let seatID, let offerID):
            eventQueue.append(
                .dragOfferChanged(
                    DragOfferChangedEvent(seatID: seatID, offerID: offerID)
                )
            )
        case .publishDragSourceCancelled, .publishDragSourceTargetChanged,
            .publishDragSourceActionChanged, .publishDragSourceDropPerformed,
            .publishDragSourceFinished:
            appendDragSourceEvent(for: effect)
        default:
            return
        }
    }

    private func appendDragSourceEvent(for effect: DataTransferEffect) {
        switch effect {
        case .publishDragSourceCancelled(let sourceID):
            eventQueue.append(.dragSourceCancelled(sourceID.dragIdentity))
        case .publishDragSourceTargetChanged(let sourceID, let mimeType):
            eventQueue.append(
                .dragSourceTargetChanged(
                    DragSourceTargetEvent(sourceID: sourceID, mimeType: mimeType)
                )
            )
        case .publishDragSourceActionChanged(let sourceID, let action):
            eventQueue.append(
                .dragSourceActionChanged(
                    DragSourceActionEvent(sourceID: sourceID, action: action)
                )
            )
        case .publishDragSourceDropPerformed(let sourceID):
            eventQueue.append(.dragSourceDropPerformed(sourceID.dragIdentity))
        case .publishDragSourceFinished(let sourceID, let finalAction):
            eventQueue.append(
                .dragSourceFinished(
                    DragSourceFinishedEvent(
                        sourceID: sourceID,
                        finalAction: finalAction
                    )
                )
            )
        default:
            return
        }
    }

    func handleDragEnter(
        _ enter: RawDataDeviceEnter,
        seatID: SeatID
    ) throws {
        guard let handle = enter.offer else {
            return
        }
        let target = surfaceTargetResolver(enter.surfaceID)
        guard let offerID = store.offerID(for: handle) else {
            throw DataTransferError.unknownOfferHandle(rawValue: handle.rawValue, seatID: seatID)
        }
        if let existingOffer = store.offerSnapshot(offerID) {
            guard case .dragAndDrop(seatID) = existingOffer.role else {
                throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
            }
            try apply(
                .dragEntered(
                    enterTransition(enter, seatID: seatID, offerID: offerID, target: target)))
            return
        }

        guard let runtimeOffer = store.runtimeOffer(offerID) else {
            throw DataTransferError.unknownDragOfferIdentity(offerID.dragIdentity)
        }
        guard runtimeOffer.pendingSeatID == seatID else {
            throw DataTransferError.mismatchedOfferSeat(
                offer: .dragAndDrop(offerID.dragIdentity),
                expected: seatID,
                actual: runtimeOffer.pendingSeatID
            )
        }
        guard !runtimeOffer.pendingMIMETypes.isEmpty else {
            throw DataTransferError.emptyDataOffer
        }

        try apply(.offerCreated(id: offerID, role: .dragAndDrop(seatID: seatID)))
        for mimeType in runtimeOffer.pendingMIMETypes {
            try apply(.offerMimeType(id: offerID, mimeType: mimeType))
        }
        try apply(.offerSourceActions(id: offerID, actions: runtimeOffer.pendingSourceActions))
        if let selectedAction = runtimeOffer.pendingSelectedAction {
            try apply(.offerSelectedAction(id: offerID, action: selectedAction))
        }
        _ = try store.markOfferActive(offerID)
        try apply(
            .dragEntered(enterTransition(enter, seatID: seatID, offerID: offerID, target: target)))
    }

    private func enterTransition(
        _ enter: RawDataDeviceEnter,
        seatID: SeatID,
        offerID: DataOfferID,
        target: InputEventTarget
    ) -> DataTransferDragEnterTransition {
        DataTransferDragEnterTransition(
            seatID: seatID,
            offerID: offerID,
            serial: InputSerial(rawValue: enter.serial),
            location: DragLocation(x: enter.x.doubleValue, y: enter.y.doubleValue),
            target: target
        )
    }
}
