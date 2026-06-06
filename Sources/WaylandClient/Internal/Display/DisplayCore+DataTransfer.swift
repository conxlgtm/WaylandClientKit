extension DisplayCore {
    func clipboardOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let offer = try activeSession.clipboardOfferOnOwnerThread(for: seatID)
            publishDrainedDataTransfer(from: activeSession)
            return offer
        }
    }

    func dragOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let offer = try activeSession.dragOfferOnOwnerThread(for: seatID)
            publishDrainedDataTransfer(from: activeSession)
            return offer
        }
    }

    func receiveClipboardOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let descriptor = try activeSession.receiveClipboardOfferOnOwnerThread(
                id: offerID,
                mimeType: mimeType
            )
            publishDrainedDataTransfer(from: activeSession)
            return descriptor
        }
    }

    func receiveDragOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let descriptor = try activeSession.receiveDragOfferOnOwnerThread(
                id: offerID,
                mimeType: mimeType
            )
            publishDrainedDataTransfer(from: activeSession)
            return descriptor
        }
    }

    func acceptDragOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType?
    ) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.acceptDragOfferOnOwnerThread(
                id: offerID,
                mimeType: mimeType
            )
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func setDragOfferActions(
        id offerID: DataOfferID,
        actions: DragActionSet,
        preferredAction: DragAction
    ) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.setDragOfferActionsOnOwnerThread(
                id: offerID,
                actions: actions,
                preferredAction: preferredAction
            )
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func finishDragOffer(id offerID: DataOfferID) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.finishDragOfferOnOwnerThread(id: offerID)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func cancelDragOffer(id offerID: DataOfferID) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.cancelDragOfferOnOwnerThread(id: offerID)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func primarySelectionOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let offer = try activeSession.primarySelectionOfferOnOwnerThread(for: seatID)
            publishDrainedDataTransfer(from: activeSession)
            return offer
        }
    }

    func receivePrimarySelectionOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let descriptor = try activeSession.receivePrimarySelectionOfferOnOwnerThread(
                id: offerID,
                mimeType: mimeType
            )
            publishDrainedDataTransfer(from: activeSession)
            return descriptor
        }
    }

    func setClipboard(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let source = try activeSession.setClipboardOnOwnerThread(
                configuration,
                seatID: seatID,
                serial: serial
            )
            publishDrainedDataTransfer(from: activeSession)
            return source
        }
    }

    func startDrag(
        from windowID: WindowID,
        source configuration: DragSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial,
        icon: DragIcon
    ) throws -> DataSourceSnapshot {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let window = try requireOpenWindow(windowID)
            let origin = try window.dataTransferDragOriginOnOwnerThread()
            let source = try activeSession.startDragOnOwnerThread(
                configuration,
                seatID: seatID,
                serial: serial,
                origin: origin,
                icon: icon
            )
            publishDrainedDataTransfer(from: activeSession)
            return source
        }
    }

    func cancelDragSource(id sourceID: DataSourceID) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.cancelDragSourceOnOwnerThread(id: sourceID)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func clearClipboard(seatID: SeatID, serial: InputSerial) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.clearClipboardOnOwnerThread(seatID: seatID, serial: serial)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func setPrimarySelection(
        _ configuration: PrimarySelectionSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let source = try activeSession.setPrimarySelectionOnOwnerThread(
                configuration,
                seatID: seatID,
                serial: serial
            )
            publishDrainedDataTransfer(from: activeSession)
            return source
        }
    }

    func clearPrimarySelection(seatID: SeatID, serial: InputSerial) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.clearPrimarySelectionOnOwnerThread(seatID: seatID, serial: serial)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func clearClipboard(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.clearClipboardOnOwnerThread(
                sourceID: sourceID,
                seatID: seatID,
                serial: serial
            )
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func clearPrimarySelection(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.clearPrimarySelectionOnOwnerThread(
                sourceID: sourceID,
                seatID: seatID,
                serial: serial
            )
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    private func publishDrainedDataTransfer(from session: DisplaySession) {
        publishDataTransferDrain(session.drainDataTransferEventsAndDiagnosticsOnOwnerThread())
    }

    package func publishDataTransferDrain(
        _ drained: DataTransferDrain
    ) {
        publishDataTransferDiagnostics(drained.diagnostics)
        publishDataTransferEvents(drained.events)
    }
}
