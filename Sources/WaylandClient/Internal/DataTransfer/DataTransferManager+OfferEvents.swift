import WaylandRaw

extension DataTransferManager {
    func handleDragOfferEvent(_ event: RawDataOfferEvent, offerID: DataOfferID) {
        guard !isShutdown else { return }
        defer { preconditionInvariantsHold() }
        do {
            switch event {
            case .offer(let rawMimeType):
                try handleMIMEType(rawMimeType, offerID: offerID)
            case .sourceActions(let rawActions):
                if selectionEngine.containsOffer(offerID) {
                    guard selectionEngine.offerSnapshot(offerID) == nil else { return }
                    pendingDragMetadataByOfferID[offerID, default: PendingDragOfferMetadata()]
                        .sourceActions = DragActionSet(rawDataDeviceDNDAction: rawActions)
                    return
                }
                try handleSourceActions(rawActions, offerID: offerID)
            case .action(let rawAction):
                if selectionEngine.containsOffer(offerID) {
                    guard selectionEngine.offerSnapshot(offerID) == nil else { return }
                    pendingDragMetadataByOfferID[offerID, default: PendingDragOfferMetadata()]
                        .selectedAction = DragAction(rawDataDeviceDNDAction: rawAction)
                    return
                }
                try handleSelectedAction(rawAction, offerID: offerID)
            }
        } catch {
            recordCallbackError(error, context: callbackContext(forOffer: offerID))
        }
    }

    func handleTransferredOfferEvent(
        _ event: SelectionEngineOfferEvent,
        offerID: DataOfferID
    ) -> Bool {
        guard store.runtimeOffer(offerID) != nil else { return false }
        defer { preconditionInvariantsHold() }

        do {
            switch event {
            case .mimeType(let rawMIMEType):
                try handleMIMEType(rawMIMEType, offerID: offerID)
            }
        } catch {
            recordCallbackError(error, context: callbackContext(forOffer: offerID))
        }
        return true
    }

    private func handleMIMEType(_ rawMimeType: String?, offerID: DataOfferID) throws {
        guard let rawMimeType, let mimeType = MIMEType(rawValue: rawMimeType) else {
            return
        }

        if store.offerSnapshot(offerID) != nil {
            try apply(.offerMimeType(id: offerID, mimeType: mimeType))
        } else {
            try store.appendPendingMIMEType(mimeType, offerID: offerID)
        }
    }

    private func handleSourceActions(
        _ rawActions: RawDataDeviceDNDAction,
        offerID: DataOfferID
    ) throws {
        let actions = DragActionSet(rawDataDeviceDNDAction: rawActions)
        if let offer = store.offerSnapshot(offerID) {
            guard case .dragAndDrop = offer.role else {
                return
            }
            try apply(.offerSourceActions(id: offerID, actions: actions))
        } else {
            try store.setPendingSourceActions(actions, offerID: offerID)
        }
    }

    private func handleSelectedAction(
        _ rawAction: RawDataDeviceDNDAction,
        offerID: DataOfferID
    ) throws {
        let action = DragAction(rawDataDeviceDNDAction: rawAction)
        if let offer = store.offerSnapshot(offerID) {
            guard case .dragAndDrop = offer.role else {
                return
            }
            try apply(.offerSelectedAction(id: offerID, action: action))
        } else {
            try store.setPendingSelectedAction(action, offerID: offerID)
        }
    }

    private func callbackContext(forOffer offerID: DataOfferID) -> DataTransferCallbackContext {
        if selectionEngine.containsOffer(offerID) {
            return .dataOffer(offerID.clipboardIdentity)
        }
        if let offer = store.offerSnapshot(offerID), case .dragAndDrop = offer.role {
            return .dragOffer(offerID.dragIdentity)
        }
        return store.runtimeOffer(offerID) == nil
            ? .dataOffer(offerID.clipboardIdentity)
            : .dragOffer(offerID.dragIdentity)
    }
}
