import WaylandRaw

struct DisplayToplevelDragRecord {
    let id: ToplevelDragID
    let windowID: WindowID
    let source: DragSourceIdentity
    let seatID: SeatID
    let serial: InputSerial
    let rawDrag: RawXDGToplevelDrag

    func destroy() {
        rawDrag.destroy()
    }
}

struct DisplayToplevelDragStartRequest {
    let windowID: WindowID
    let configuration: DragSourceConfiguration
    let seatID: SeatID
    let serial: InputSerial
    let icon: DragIcon
    let offset: LogicalOffset

    var dragStartRequest: DisplayStartDragRequest {
        DisplayStartDragRequest(
            windowID: windowID,
            configuration: configuration,
            seatID: seatID,
            serial: serial,
            icon: icon,
            toplevelDragOffset: offset
        )
    }
}

struct DisplayStartDragRequest {
    let windowID: WindowID
    let configuration: DragSourceConfiguration
    let seatID: SeatID
    let serial: InputSerial
    let icon: DragIcon
    let toplevelDragOffset: LogicalOffset?
}

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
        try startDrag(
            DisplayStartDragRequest(
                windowID: windowID,
                configuration: configuration,
                seatID: seatID,
                serial: serial,
                icon: icon,
                toplevelDragOffset: nil
            )
        ).source
    }

    func startToplevelDrag(
        _ request: DisplayToplevelDragStartRequest
    ) throws -> (source: DataSourceSnapshot, dragID: ToplevelDragID) {
        let result = try startDrag(request.dragStartRequest)
        guard let dragID = result.dragID else {
            throw ClientError.display(.xdgToplevelDragUnavailable)
        }

        return (result.source, dragID)
    }

    private func startDrag(
        _ request: DisplayStartDragRequest
    ) throws -> (source: DataSourceSnapshot, dragID: ToplevelDragID?) {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let window = try requireOpenWindow(request.windowID)
            return try startDragOnOwnerThread(
                request,
                activeSession: activeSession,
                window: window
            )
        }
    }

    private func startDragOnOwnerThread(
        _ request: DisplayStartDragRequest,
        activeSession: DisplaySession,
        window: TopLevelWindow
    ) throws -> (source: DataSourceSnapshot, dragID: ToplevelDragID?) {
        let origin = try window.dataTransferDragOriginOnOwnerThread()
        let manager = try bindToplevelDragManagerIfNeeded(
            offset: request.toplevelDragOffset,
            session: activeSession
        )
        defer { manager?.destroy() }

        var rawDrag: RawXDGToplevelDrag?
        let beforeStartDrag = toplevelDragSetupHook(
            manager: manager,
            window: window,
            offset: request.toplevelDragOffset
        ) { rawDrag = $0 }

        do {
            let source = try activeSession.startDragOnOwnerThread(
                request.configuration,
                seatID: request.seatID,
                serial: request.serial,
                origin: origin,
                icon: request.icon,
                beforeStartDrag: beforeStartDrag
            )
            let dragID = recordToplevelDragIfNeeded(
                rawDrag: rawDrag,
                request: request,
                source: source
            )
            publishDrainedDataTransfer(from: activeSession)
            return (source, dragID)
        } catch {
            rawDrag?.destroy()
            throw error
        }
    }

    private func bindToplevelDragManagerIfNeeded(
        offset: LogicalOffset?,
        session: DisplaySession
    ) throws -> RawXDGToplevelDragManager? {
        guard offset != nil else { return nil }
        guard let manager = try session.connection.bindXDGToplevelDragManagerOneShot() else {
            throw ClientError.display(.xdgToplevelDragUnavailable)
        }
        return manager
    }

    private func toplevelDragSetupHook(
        manager: RawXDGToplevelDragManager?,
        window: TopLevelWindow,
        offset: LogicalOffset?,
        recordRawDrag: @escaping (RawXDGToplevelDrag) -> Void
    ) -> ((any DataTransferSourceBinding) throws -> Void)? {
        guard let manager, let offset else { return nil }
        return { sourceBinding in
            let drag = try sourceBinding.createToplevelDrag(manager: manager)
            do {
                try window.attachToplevelDragOnOwnerThread(drag, offset: offset)
                recordRawDrag(drag)
            } catch {
                drag.destroy()
                throw error
            }
        }
    }

    private func recordToplevelDragIfNeeded(
        rawDrag: RawXDGToplevelDrag?,
        request: DisplayStartDragRequest,
        source: DataSourceSnapshot
    ) -> ToplevelDragID? {
        guard let rawDrag else { return nil }

        let dragID = toplevelDragIDs.next()
        let record = DisplayToplevelDragRecord(
            id: dragID,
            windowID: request.windowID,
            source: source.id.dragIdentity,
            seatID: request.seatID,
            serial: request.serial,
            rawDrag: rawDrag
        )
        toplevelDragsByID[dragID] = record
        toplevelDragIDsByWindowID[request.windowID, default: []].append(dragID)
        closedToplevelDragIDs.remove(dragID)
        return dragID
    }

    func cancelDragSource(id sourceID: DataSourceID) throws {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            try activeSession.cancelDragSourceOnOwnerThread(id: sourceID)
            publishDrainedDataTransfer(from: activeSession)
        }
    }

    func destroyToplevelDrag(_ dragID: ToplevelDragID) throws {
        try withFatalFailureFinalization {
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
            guard toplevelDragsByID[dragID] != nil else {
                if closedToplevelDragIDs.contains(dragID) {
                    return
                }

                throw ClientError.display(.unknownToplevelDrag(dragID))
            }

            throw ClientError.display(.toplevelDragStillActive(dragID))
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

    func closeToplevelDrags(for source: DragSourceIdentity) {
        for record in Array(toplevelDragsByID.values) where record.source == source {
            closeToplevelDrag(record.id)
        }
    }

    func closeToplevelDrag(_ dragID: ToplevelDragID) {
        guard let record = toplevelDragsByID.removeValue(forKey: dragID) else {
            return
        }

        record.destroy()
        if var windowDrags = toplevelDragIDsByWindowID[record.windowID] {
            windowDrags.removeAll { $0 == dragID }
            if windowDrags.isEmpty {
                toplevelDragIDsByWindowID.removeValue(forKey: record.windowID)
            } else {
                toplevelDragIDsByWindowID[record.windowID] = windowDrags
            }
        }
        closedToplevelDragIDs.insert(dragID)
    }

    func removeAllToplevelDrags() {
        let records = Array(toplevelDragsByID.values)
        toplevelDragsByID.removeAll(keepingCapacity: false)
        toplevelDragIDsByWindowID.removeAll(keepingCapacity: false)
        closedToplevelDragIDs.formUnion(records.map(\.id))
        for record in records {
            record.destroy()
        }
    }
}
