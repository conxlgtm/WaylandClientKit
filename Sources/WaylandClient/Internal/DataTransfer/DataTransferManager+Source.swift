import WaylandRaw

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
            case .target, .dndDropPerformed, .dndFinished, .action:
                break
            }
            preconditionInvariantsHold()
        } catch {
            recordCallbackError(error, context: .dataSource(ClipboardSourceIdentity(sourceID)))
        }
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
                DataTransferSourceSendRequest(
                    source: .clipboard(sourceID),
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
            if request.source == .clipboard(sourceID) {
                do {
                    try request.close()
                } catch {
                    recordCallbackError(
                        error,
                        context: .dataSource(ClipboardSourceIdentity(sourceID))
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
