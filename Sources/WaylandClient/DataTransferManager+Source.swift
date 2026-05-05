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
            guard case .cancelled = event else {
                return
            }

            try apply(.sourceCancelled(sourceID))
        } catch {
            pendingCallbackError = error
        }
    }

    private func allocateSourceID() -> DataSourceID {
        defer { nextSourceID += 1 }
        return DataSourceID(rawValue: nextSourceID)
    }
}
