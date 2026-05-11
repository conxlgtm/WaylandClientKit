import WaylandRaw

extension DataTransferManager {
    private static let minimumDragActionNegotiationVersion = RawVersion(3)

    package func receiveOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let offer = store.offerSnapshot(offerID) else {
            throw DataTransferError.unknownOfferIdentity(ClipboardOfferIdentity(offerID))
        }
        guard offer.mimeTypes.contains(mimeType) else {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }
        guard let binding = offerBindingsByID[offerID] else {
            throw DataTransferError.offerExpired
        }

        let descriptors = try backend.makeOfferReceivePipe()
        var readEnd = try adoptReadEnd(descriptors)
        try receiveIntoPipe(
            binding,
            mimeType: mimeType,
            descriptors: descriptors,
            readEnd: &readEnd
        )
        return readEnd
    }

    package func receiveDragOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        _ = try dragOffer(id: offerID)
        return try receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func acceptDragOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType?
    ) throws {
        backend.preconditionIsOwnerThread()
        let offer = try dragOffer(id: offerID)
        guard let serial = offer.dragAndDrop?.enterSerial else {
            throw DataTransferError.dragOfferNotActive(DragOfferIdentity(offerID))
        }
        if let mimeType, !offer.mimeTypes.contains(mimeType) {
            throw DataTransferError.mimeTypeUnavailable(mimeType)
        }
        guard let binding = offerBindingsByID[offerID] else {
            throw DataTransferError.offerExpired
        }

        try apply(.dragAccepted(id: offerID, mimeType: mimeType))
        binding.accept(serial: serial, mimeType: mimeType)
    }

    package func setDragOfferActions(
        id offerID: DataOfferID,
        actions: DragActionSet,
        preferredAction: DragAction
    ) throws {
        backend.preconditionIsOwnerThread()
        let offer = try dragOffer(id: offerID)
        guard let binding = offerBindingsByID[offerID] else {
            throw DataTransferError.offerExpired
        }
        try requireDragActionNegotiation(on: binding, offerID: offerID)
        guard actions.containsOnlyKnownProtocolActions else {
            throw DataTransferError.invalidDragActionSet(rawValue: actions.rawValue)
        }
        guard preferredAction.isKnownProtocolAction else {
            throw DataTransferError.invalidDragAction(
                rawValue: preferredAction.rawDataDeviceDNDAction.rawValue
            )
        }
        if preferredAction != .none, !actions.contains(preferredAction.actionSetMember) {
            throw DataTransferError.unsupportedDragAction(
                action: preferredAction,
                available: actions
            )
        }
        if preferredAction != .none,
            offer.dragAndDrop?.sourceActions.contains(preferredAction.actionSetMember) != true
        {
            throw DataTransferError.unsupportedDragAction(
                action: preferredAction,
                available: offer.dragAndDrop?.sourceActions ?? []
            )
        }
        try requireAllowedDragActionRequest(offer, preferredAction: preferredAction)

        try apply(.dragActionsRequested(id: offerID, preferredAction: preferredAction))
        binding.setDragActions(actions, preferredAction: preferredAction)
    }

    package func finishDragOffer(id offerID: DataOfferID) throws {
        backend.preconditionIsOwnerThread()
        let offer = try dragOffer(id: offerID)
        guard let binding = offerBindingsByID[offerID] else {
            throw DataTransferError.offerExpired
        }
        try requireDragActionNegotiation(on: binding, offerID: offerID)
        try requireFinishableDragOffer(offer)

        binding.finish()
        try apply(.dragFinished(offerID))
        preconditionInvariantsHold()
    }

    package func cancelDragOffer(id offerID: DataOfferID) throws {
        backend.preconditionIsOwnerThread()
        _ = try dragOffer(id: offerID)

        try apply(.dragCancelled(offerID))
        preconditionInvariantsHold()
    }

    private func requireDragActionNegotiation(
        on binding: any DataTransferOfferBinding,
        offerID: DataOfferID
    ) throws {
        guard binding.protocolVersion >= Self.minimumDragActionNegotiationVersion else {
            throw DataTransferError.dragActionNegotiationUnavailable(
                DragOfferIdentity(offerID)
            )
        }
    }

    private func requireAllowedDragActionRequest(
        _ offer: DataOfferSnapshot,
        preferredAction: DragAction
    ) throws {
        guard let metadata = offer.dragAndDrop, metadata.hasDropped else {
            return
        }

        guard metadata.selectedAction == .received(.ask),
            preferredAction.isFinalTransferAction
        else {
            throw DataTransferError.dragActionRequestNotAllowed(DragOfferIdentity(offer.id))
        }
    }

    private func requireFinishableDragOffer(_ offer: DataOfferSnapshot) throws {
        guard let metadata = offer.dragAndDrop,
            metadata.hasDropped,
            metadata.selectedAction.isFinishable(
                finalPreferredAction: metadata.finalPreferredAction
            ),
            case .accepted = metadata.acceptState
        else {
            throw DataTransferError.dragOfferNotFinishable(DragOfferIdentity(offer.id))
        }
    }

    private func adoptReadEnd(
        _ descriptors: DataTransferPipeDescriptors
    ) throws -> OwnedFileDescriptor {
        do {
            return try backend.adoptOwnedFileDescriptor(descriptors.readEnd)
        } catch {
            closePipeDescriptorIfValid(descriptors.readEnd)
            closePipeDescriptorIfValid(descriptors.writeEnd)
            throw error
        }
    }

    private func receiveIntoPipe(
        _ binding: any DataTransferOfferBinding,
        mimeType: MIMEType,
        descriptors: DataTransferPipeDescriptors,
        readEnd: inout OwnedFileDescriptor
    ) throws {
        var rawWriteEnd: Int32? = descriptors.writeEnd
        do {
            var writeEnd = try backend.adoptOwnedFileDescriptor(descriptors.writeEnd)
            rawWriteEnd = nil
            binding.receive(mimeType: mimeType, fd: writeEnd.rawValue)
            try writeEnd.close()
        } catch {
            if let rawWriteEnd {
                closePipeDescriptorIfValid(rawWriteEnd)
            }
            do {
                try readEnd.close()
            } catch {
                _ = error
            }
            throw error
        }
    }

    private func closePipeDescriptorIfValid(_ descriptor: Int32) {
        guard descriptor >= 0 else { return }
        _ = backend.closeFileDescriptor(descriptor)
    }
}
