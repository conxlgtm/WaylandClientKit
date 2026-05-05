import WaylandRaw

extension DataTransferManager {
    package func setSelectionSource(
        seatID: SeatID,
        mimeTypes: [MIMEType],
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
            for mimeType in mimeTypes {
                sourceBinding.offer(mimeType: mimeType)
            }
            try apply(.sourceCreated(id: sourceID, seatID: seatID, mimeTypes: mimeTypes))
            sourceBindingsByID[sourceID] = sourceBinding
            try apply(.selectionSourceChanged(seatID: seatID, sourceID: sourceID))
            deviceBinding.setSelection(source: sourceBinding, serial: serial)
        } catch {
            sourceBinding.destroy()
            sourceBindingsByID[sourceID] = nil
            throw error
        }

        guard let source = state.sourceSnapshot(sourceID) else {
            throw DataTransferError.unknownSource
        }

        return source
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
    }

    private func selectionDeviceBinding(
        for seatID: SeatID
    ) throws -> any DataTransferDeviceBinding {
        guard let seat = state.seatSnapshot(seatID) else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        guard let deviceBinding = deviceBindings[seatID] else {
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
            case .target, .dndDropPerformed, .dndFinished, .action:
                break
            }
        } catch {
            pendingCallbackError = error
        }
    }

    private func handleDataSourceSend(
        mimeType rawMimeType: String?,
        descriptor: Int32,
        sourceID: DataSourceID
    ) throws {
        do {
            guard let source = state.sourceSnapshot(sourceID) else {
                throw DataTransferError.unknownSource
            }
            let mimeType = try MIMEType(rawMimeType ?? "")
            guard source.mimeTypes.contains(mimeType) else {
                throw DataTransferError.mimeTypeUnavailable(mimeType)
            }

            throw DataTransferError.sourceDataUnavailable(mimeType)
        } catch {
            try closeSourceSendDescriptor(descriptor)
            throw error
        }
    }

    private func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        let closeResult = backend.closeFileDescriptor(descriptor)
        guard closeResult == 0 else {
            throw DataTransferError.closeFileDescriptor(
                WaylandSystemErrno(unchecked: closeResult)
            )
        }
    }

    private func allocateSourceID() -> DataSourceID {
        defer { nextSourceID += 1 }
        return DataSourceID(rawValue: nextSourceID)
    }
}
