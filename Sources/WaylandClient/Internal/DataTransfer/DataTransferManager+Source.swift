import WaylandRaw

extension DataTransferManager {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        return store.drainSourceSendRequests()
    }

    package func drainSourceWriteJobs() throws -> [DataTransferSourceWriteJob] {
        try DataTransferSourceSendLifecycle.makeWriteJobs(
            from: drainSourceSendRequests(),
            recordDiscardError: recordSourceSendDiscardError
        )
    }

    package func setSelectionSource(
        seatID: SeatID,
        payloads: DataTransferSourcePayloadSet,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let deviceBinding = try selectionDeviceBinding(for: seatID)
        let sourceID = allocateSourceID()
        let callbackIdentity = DataSourceCallbackIdentity.selection(
            sourceID.clipboardIdentity
        )
        let sourceBinding = try createDataSourceBinding(
            sourceID: sourceID,
            callbackIdentity: callbackIdentity
        )
        do {
            for mimeType in payloads.mimeTypes {
                sourceBinding.offer(mimeType: mimeType)
            }
            try store.insertSource(
                binding: sourceBinding,
                payloads: payloads,
                sourceID: sourceID
            )
            try apply(.sourceCreated(id: sourceID, seatID: seatID, mimeTypes: payloads.mimeTypes))
            try apply(.selectionSourceChanged(seatID: seatID, sourceID: sourceID))
            deviceBinding.setSelection(source: sourceBinding, serial: serial)
            preconditionInvariantsHold()
        } catch {
            sourceBinding.destroy()
            store.removeSource(sourceID)
            throw error
        }

        guard let source = store.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownSourceIdentity(sourceID.clipboardIdentity)
        }

        preconditionInvariantsHold()
        return source
    }

    package func startDrag(_ request: DataTransferStartDragRequest) throws -> DataSourceSnapshot {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard !request.actions.isEmpty, request.actions.containsOnlyKnownProtocolActions else {
            throw DataTransferError.invalidDragActionSet(rawValue: request.actions.rawValue)
        }
        let deviceBinding = try selectionDeviceBinding(for: request.seatID)
        let sourceID = allocateSourceID()
        guard deviceBinding.protocolVersion >= RawVersion(3) else {
            throw DataTransferError.dragSourceActionNegotiationUnavailable(
                sourceID.dragIdentity
            )
        }

        let sourceBinding = try createDragSourceBinding(sourceID: sourceID)
        var iconBinding: (any DataTransferDragIconBinding)?
        do {
            iconBinding = try backend.prepareDragIcon(request.icon)
            for mimeType in request.payloads.mimeTypes {
                sourceBinding.offer(mimeType: mimeType)
            }
            sourceBinding.setDragActions(request.actions)
            try request.beforeStartDrag?(sourceBinding)
            try store.insertSource(
                binding: sourceBinding,
                payloads: request.payloads,
                sourceID: sourceID
            )
            try apply(
                .dragSourceCreated(
                    id: sourceID,
                    seatID: request.seatID,
                    mimeTypes: request.payloads.mimeTypes,
                    actions: request.actions
                )
            )
            deviceBinding.startDrag(
                source: sourceBinding,
                origin: request.origin,
                icon: iconBinding,
                serial: request.serial
            )
            sourceBinding.attachDragIcon(iconBinding)
            iconBinding = nil
            preconditionInvariantsHold()
        } catch {
            iconBinding?.destroy()
            sourceBinding.destroy()
            store.removeSource(sourceID)
            throw error
        }

        guard let source = store.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownDragSourceIdentity(sourceID.dragIdentity)
        }

        preconditionInvariantsHold()
        return source
    }

    package func cancelDragSource(id sourceID: DataSourceID) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard sourceIsDragAndDrop(sourceID) else {
            throw DataTransferError.unknownDragSourceIdentity(sourceID.dragIdentity)
        }

        try apply(.sourceCancelled(sourceID))
        preconditionInvariantsHold()
    }

    package func clearSelectionSource(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let deviceBinding = try selectionDeviceBinding(for: seatID)
        deviceBinding.setSelection(source: nil, serial: serial)
        try apply(.selectionSourceChanged(seatID: seatID, sourceID: nil))
        preconditionInvariantsHold()
    }

    package func clearSelectionSource(
        id sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        guard let seat = store.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.selectionSourceID == sourceID else {
            throw DataTransferError.sourceCancelled
        }

        let deviceBinding = try selectionDeviceBinding(for: seatID)
        deviceBinding.setSelection(source: nil, serial: serial)
        try apply(.selectionSourceChanged(seatID: seatID, sourceID: nil))
        preconditionInvariantsHold()
    }

    private func selectionDeviceBinding(
        for seatID: SeatID
    ) throws -> any DataTransferDeviceBinding {
        guard let seat = store.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        guard let deviceBinding = store.deviceBinding(for: seatID) else {
            throw DataTransferError.missingDataDevice(seatID)
        }

        return deviceBinding
    }

    private func createDataSourceBinding(
        sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) throws -> any DataTransferSourceBinding {
        try backend.createDataSource(id: sourceID) { [weak self] event in
            self?.handleDataSourceEvent(
                event,
                sourceID: sourceID,
                callbackIdentity: callbackIdentity
            )
        }
    }

    private func createDragSourceBinding(
        sourceID: DataSourceID
    ) throws -> any DataTransferSourceBinding {
        let callbackIdentity = DataSourceCallbackIdentity.dragAndDrop(
            sourceID.dragIdentity
        )
        let sourceBinding = try createDataSourceBinding(
            sourceID: sourceID,
            callbackIdentity: callbackIdentity
        )
        guard sourceBinding.protocolVersion >= RawVersion(3) else {
            sourceBinding.destroy()
            throw DataTransferError.dragSourceActionNegotiationUnavailable(
                sourceID.dragIdentity
            )
        }

        return sourceBinding
    }

    private func handleDataSourceEvent(
        _ event: RawDataSourceEvent,
        sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) {
        guard !isShutdown else {
            closeLateDataSourceSendIfNeeded(event, callbackIdentity: callbackIdentity)
            return
        }
        do {
            switch event {
            case .send(let rawMimeType, let descriptor):
                try handleDataSourceSend(
                    mimeType: rawMimeType,
                    descriptor: descriptor,
                    sourceID: sourceID,
                    callbackIdentity: callbackIdentity
                )
            case .cancelled:
                try apply(.sourceCancelled(sourceID))
            case .target(let rawMimeType):
                try handleDataSourceTarget(
                    mimeType: rawMimeType,
                    sourceID: sourceID,
                    callbackIdentity: callbackIdentity
                )
            case .dndDropPerformed:
                let source = try sourceSnapshot(
                    for: sourceID,
                    callbackIdentity: callbackIdentity
                )
                try handleDragSourceOnlyEvent(.dndDropPerformed, for: source) {
                    try apply(.dragSourceDropPerformed(sourceID))
                }
            case .dndFinished:
                let source = try sourceSnapshot(
                    for: sourceID,
                    callbackIdentity: callbackIdentity
                )
                try handleDragSourceOnlyEvent(.dndFinished, for: source) {
                    try finishDragSourceFromCallback(sourceID)
                }
            case .action(let action):
                let source = try sourceSnapshot(
                    for: sourceID,
                    callbackIdentity: callbackIdentity
                )
                try handleDragSourceOnlyEvent(.action, for: source) {
                    try apply(
                        .dragSourceActionChanged(
                            id: sourceID,
                            action: DragAction(rawDataDeviceDNDAction: action)
                        )
                    )
                }
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: callbackIdentity.context)
        }
    }

    private func closeLateDataSourceSendIfNeeded(
        _ event: RawDataSourceEvent,
        callbackIdentity: DataSourceCallbackIdentity
    ) {
        guard case .send(_, let descriptor) = event else {
            return
        }

        do {
            try closeSourceSendDescriptor(descriptor)
        } catch {
            recordCallbackError(error, context: callbackIdentity.context)
        }
    }

    private func sourceSnapshot(
        for sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) throws -> DataSourceSnapshot {
        guard let source = store.sourceSnapshot(sourceID) else {
            throw callbackIdentity.unknownSourceError
        }

        return source
    }

    private func handleDragSourceOnlyEvent(
        _ eventKind: DataSourceCallbackEventKind,
        for source: DataSourceSnapshot,
        _ operation: () throws -> Void
    ) throws {
        guard case .dragAndDrop = source.role else {
            throw DataTransferError.invalidSourceEvent(eventKind)
        }

        try operation()
    }

    private func finishDragSourceFromCallback(_ sourceID: DataSourceID) throws {
        do {
            try apply(.dragSourceFinished(sourceID))
        } catch {
            do {
                try apply(.dragSourceInvalidFinished(sourceID))
            } catch {
                preconditionFailure("invalid drag source finish cleanup failed: \(error)")
            }
            throw error
        }
    }

    private func sourceIsDragAndDrop(_ sourceID: DataSourceID) -> Bool {
        guard case .dragAndDrop = store.sourceSnapshot(sourceID)?.role else {
            return false
        }

        return true
    }

    private func writeSource(
        for sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) throws -> DataTransferSourceWriteSource {
        guard let source = store.sourceSnapshot(sourceID) else {
            throw callbackIdentity.unknownSourceError
        }

        switch source.role {
        case .selection:
            return .clipboard(sourceID)
        case .dragAndDrop:
            return .dragAndDrop(sourceID)
        }
    }

    private func handleDataSourceTarget(
        mimeType rawMimeType: String?,
        sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) throws {
        guard let source = store.sourceSnapshot(sourceID) else {
            if callbackIdentity.isSelection {
                return
            }
            throw callbackIdentity.unknownSourceError
        }

        switch source.role {
        case .selection:
            return
        case .dragAndDrop:
            try handleDragSourceTarget(mimeType: rawMimeType, sourceID: sourceID)
        }
    }

    private func handleDragSourceTarget(
        mimeType rawMimeType: String?,
        sourceID: DataSourceID
    ) throws {
        let mimeType = try normalizedCallbackMIMEType(rawMimeType)
        if let mimeType {
            guard store.sourceSnapshot(sourceID)?.mimeTypes.contains(mimeType) == true else {
                throw DataTransferError.mimeTypeUnavailable(mimeType)
            }
        }
        try apply(.dragSourceTargetChanged(id: sourceID, mimeType: mimeType))
    }

    private func handleDataSourceSend(
        mimeType rawMimeType: String?,
        descriptor: Int32,
        sourceID: DataSourceID,
        callbackIdentity: DataSourceCallbackIdentity
    ) throws {
        guard let mimeType = try normalizedCallbackMIMEType(rawMimeType) else {
            try closeSourceSendDescriptor(descriptor)
            return
        }

        do {
            guard let source = store.sourceSnapshot(sourceID) else {
                throw callbackIdentity.unknownSourceError
            }
            guard source.mimeTypes.contains(mimeType) else {
                throw DataTransferError.mimeTypeUnavailable(mimeType)
            }
            guard
                let data = store.sourcePayloadData(
                    sourceID: sourceID,
                    mimeType: mimeType
                )
            else {
                throw DataTransferError.sourceDataUnavailable(mimeType)
            }

            let requestSource = try writeSource(
                for: sourceID,
                callbackIdentity: callbackIdentity
            )
            store.appendSourceSendRequest(
                try DataTransferSourceSendRequest(
                    source: requestSource,
                    mimeType: mimeType,
                    descriptor: descriptor,
                    data: data,
                    descriptorIO: backend.sourceDescriptorIO
                )
            )
            eventQueue.append(
                .sourceSendRequested(
                    DataTransferSourceTransferEvent(
                        source: requestSource.diagnosticSource,
                        mimeType: mimeType
                    )
                )
            )
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }
    }

    private func normalizedCallbackMIMEType(_ rawMimeType: String?) throws -> MIMEType? {
        guard let rawMimeType, !rawMimeType.isEmpty else {
            return nil
        }
        return try MIMEType(rawMimeType)
    }

    private func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        try DataTransferSourceSendLifecycle.closeCallbackDescriptor(
            descriptor,
            close: backend.closeFileDescriptor
        )
    }

    package func discardPendingSourceSendRequests(for sourceID: DataSourceID) {
        DataTransferSourceSendLifecycle.discardRequests(
            store.removeSourceSendRequests(for: sourceID),
            recordError: recordSourceSendDiscardError
        )
    }

    func discardAllPendingSourceSendRequests() {
        DataTransferSourceSendLifecycle.discardRequests(
            store.drainSourceSendRequests()
        ) { _, _ in
            // Discard-all runs during teardown, so pending close failures cannot be routed.
        }
    }

    private func recordSourceSendDiscardError(
        request: DataTransferSourceSendRequest,
        error: any Error
    ) {
        recordCallbackError(
            error,
            context: .sourceWrite(request.source.diagnosticSource)
        )
    }

    private func allocateSourceID() -> DataSourceID {
        sourceIDs.next()
    }
}
