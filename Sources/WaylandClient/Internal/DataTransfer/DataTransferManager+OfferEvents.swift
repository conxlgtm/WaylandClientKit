import WaylandRaw

extension DataTransferManager {
    func handleDataOfferEvent(_ event: RawDataOfferEvent, offerID: DataOfferID) {
        do {
            switch event {
            case .offer(let rawMimeType):
                try handleMIMEType(rawMimeType, offerID: offerID)
            case .sourceActions(let rawActions):
                try handleSourceActions(rawActions, offerID: offerID)
            case .action(let rawAction):
                try handleSelectedAction(rawAction, offerID: offerID)
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: callbackContext(forOffer: offerID))
        }
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
        if let offer = store.offerSnapshot(offerID), case .dragAndDrop = offer.role {
            return .dragOffer(offerID.dragIdentity)
        }

        return .dataOffer(offerID.clipboardIdentity)
    }
}
