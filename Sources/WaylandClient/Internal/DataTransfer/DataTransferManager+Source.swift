import WaylandRaw

package struct DataTransferStartDragRequest {
    package let seatID: SeatID
    package let payloads: DataTransferSourcePayloadSet
    package let actions: DragActionSet
    package let serial: InputSerial
    package let origin: any DataTransferDragOriginBinding
    package let icon: DragIcon

    package init(
        seatID requestSeatID: SeatID,
        payloads requestPayloads: DataTransferSourcePayloadSet,
        actions requestActions: DragActionSet,
        serial requestSerial: InputSerial,
        origin requestOrigin: any DataTransferDragOriginBinding,
        icon requestIcon: DragIcon
    ) {
        seatID = requestSeatID
        payloads = requestPayloads
        actions = requestActions
        serial = requestSerial
        origin = requestOrigin
        icon = requestIcon
    }
}

extension DataTransferManager {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        return store.drainSourceSendRequests()
    }

    package func drainSourceWriteJobs() throws -> [DataTransferSourceWriteJob] {
        let requests = drainSourceSendRequests()
        var jobs: [DataTransferSourceWriteJob] = []

        for index in requests.indices {
            do {
                jobs.append(try requests[index].makeWriteJob())
            } catch {
                discardSourceWriteJobs(jobs)
                discardRemainingSourceSendRequests(requests[(index + 1)...])
                throw error
            }
        }

        return jobs
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
        let sourceBinding = try backend.createDataSource(id: sourceID) { [weak self] event in
            self?.handleDataSourceEvent(event, sourceID: sourceID)
        }
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
            throw DataTransferError.unknownSourceIdentity(ClipboardSourceIdentity(sourceID))
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
                DragSourceIdentity(sourceID)
            )
        }

        let sourceBinding = try backend.createDataSource(id: sourceID) { [weak self] event in
            self?.handleDataSourceEvent(event, sourceID: sourceID)
        }
        do {
            guard sourceBinding.protocolVersion >= RawVersion(3) else {
                throw DataTransferError.dragSourceActionNegotiationUnavailable(
                    DragSourceIdentity(sourceID)
                )
            }

            for mimeType in request.payloads.mimeTypes {
                sourceBinding.offer(mimeType: mimeType)
            }
            sourceBinding.setDragActions(request.actions)
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
                icon: request.icon,
                serial: request.serial
            )
            preconditionInvariantsHold()
        } catch {
            sourceBinding.destroy()
            store.removeSource(sourceID)
            throw error
        }

        guard let source = store.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownDragSourceIdentity(DragSourceIdentity(sourceID))
        }

        preconditionInvariantsHold()
        return source
    }

    package func cancelDragSource(id sourceID: DataSourceID) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()
        guard sourceIsDragAndDrop(sourceID) else {
            throw DataTransferError.unknownDragSourceIdentity(DragSourceIdentity(sourceID))
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

    private func handleDataSourceEvent(
        _ event: RawDataSourceEvent,
        sourceID: DataSourceID
    ) {
        do {
            switch event {
            case .send(let rawMimeType, let descriptor):
                try handleDataSourceSend(
                    mimeType: rawMimeType,
                    descriptor: descriptor,
                    sourceID: sourceID
                )
            case .cancelled:
                try apply(.sourceCancelled(sourceID))
            case .target(let rawMimeType):
                let source = try sourceSnapshot(for: sourceID)
                try handleDragSourceOnlyEvent(.target, for: source) {
                    try handleDataSourceTarget(mimeType: rawMimeType, sourceID: sourceID)
                }
            case .dndDropPerformed:
                let source = try sourceSnapshot(for: sourceID)
                try handleDragSourceOnlyEvent(.dndDropPerformed, for: source) {
                    try apply(.dragSourceDropPerformed(sourceID))
                }
            case .dndFinished:
                let source = try sourceSnapshot(for: sourceID)
                try handleDragSourceOnlyEvent(.dndFinished, for: source) {
                    try apply(.dragSourceFinished(sourceID))
                }
            case .action(let action):
                let source = try sourceSnapshot(for: sourceID)
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
            recordCallbackError(error, context: callbackContext(for: sourceID))
        }
    }

    private func sourceSnapshot(for sourceID: DataSourceID) throws -> DataSourceSnapshot {
        guard let source = store.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownSourceIdentity(ClipboardSourceIdentity(sourceID))
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

    private func sourceIsDragAndDrop(_ sourceID: DataSourceID) -> Bool {
        guard case .dragAndDrop = store.sourceSnapshot(sourceID)?.role else {
            return false
        }

        return true
    }

    private func callbackContext(for sourceID: DataSourceID) -> DataTransferCallbackContext {
        guard case .dragAndDrop = store.sourceSnapshot(sourceID)?.role else {
            return .dataSource(ClipboardSourceIdentity(sourceID))
        }

        return .dragSource(DragSourceIdentity(sourceID))
    }

    private func writeSource(for sourceID: DataSourceID) throws -> DataTransferSourceWriteSource {
        guard let source = store.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownSourceIdentity(ClipboardSourceIdentity(sourceID))
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
        sourceID: DataSourceID
    ) throws {
        let mimeType = try rawMimeType.map { try MIMEType($0) }
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
        sourceID: DataSourceID
    ) throws {
        do {
            guard let source = store.sourceSnapshot(sourceID) else {
                throw DataTransferError.unknownSourceIdentity(
                    ClipboardSourceIdentity(sourceID)
                )
            }
            let mimeType = try MIMEType(rawMimeType ?? "")
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

            store.appendSourceSendRequest(
                try DataTransferSourceSendRequest(
                    source: try writeSource(for: sourceID),
                    mimeType: mimeType,
                    descriptor: descriptor,
                    data: data,
                    descriptorIO: backend.sourceDescriptorIO
                )
            )
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }
    }

    private func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        guard descriptor >= 0 else {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        switch backend.closeFileDescriptor(descriptor) {
        case .closed:
            return
        case .failed(let error):
            throw DataTransferError.closeFileDescriptor(error)
        }
    }

    package func discardPendingSourceSendRequests(for sourceID: DataSourceID) {
        var remainingRequests: [DataTransferSourceSendRequest] = []
        for request in store.drainSourceSendRequests() {
            if request.source.sourceID == sourceID {
                do {
                    try request.close()
                } catch {
                    recordCallbackError(
                        error,
                        context: .sourceWrite(request.source.diagnosticSource)
                    )
                }
            } else {
                remainingRequests.append(request)
            }
        }

        store.replaceSourceSendRequests(remainingRequests)
    }

    func discardAllPendingSourceSendRequests() {
        for request in store.drainSourceSendRequests() {
            do {
                try request.close()
            } catch {
                _ = error
            }
        }
    }

    private func discardSourceWriteJobs(_ jobs: [DataTransferSourceWriteJob]) {
        for job in jobs {
            _ = job.closeAsCancelled()
        }
    }

    private func discardRemainingSourceSendRequests(
        _ requests: ArraySlice<DataTransferSourceSendRequest>
    ) {
        for request in requests {
            do {
                try request.close()
            } catch {
                recordCallbackError(
                    error,
                    context: .sourceWrite(request.source.diagnosticSource)
                )
            }
        }
    }

    private func allocateSourceID() -> DataSourceID {
        defer { nextSourceID += 1 }
        return DataSourceID(rawValue: nextSourceID)
    }
}
