import WaylandRaw

extension DisplaySession {
    package func drainDataTransferDiagnosticsOnOwnerThread() -> [DataTransferDiagnostic] {
        connection.preconditionIsOwnerThread()
        collectDataTransferSourceWriteResults()
        defer { pendingDataTransferDiagnostics.removeAll(keepingCapacity: true) }
        return pendingDataTransferDiagnostics
    }

    package func clipboardOfferOnOwnerThread(for seatID: SeatID) throws -> DataOfferSnapshot? {
        connection.preconditionIsOwnerThread()
        try processDataTransferState()
        return try dataTransferManager.selectionOffer(for: seatID)
    }

    package func receiveClipboardOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processDataTransferState()
        return try dataTransferManager.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func processDataTransferState() throws {
        collectDataTransferSourceWriteResults()
        try dataTransferManager.throwPendingCallbackErrorIfAny()

        guard let globals = connection.boundGlobals else {
            return
        }
        guard case .bound = globals.extensions.dataDeviceManager else {
            return
        }

        try dataTransferManager.synchronizeSeats(
            globals.seatRegistry.seats.map { SeatID(rawValue: $0.id.rawValue) }
        )
        try submitPendingDataTransferSourceWrites()
    }

    private func submitPendingDataTransferSourceWrites() throws {
        let jobs = try dataTransferManager.drainSourceWriteJobs()
        dataTransferSourceWriter.submit(jobs)
    }

    private func collectDataTransferSourceWriteResults() {
        for result in dataTransferSourceWriter.drainResults() {
            guard case .failed(let sourceID, let mimeType, let error) = result else {
                continue
            }

            pendingDataTransferDiagnostics.append(
                DataTransferDiagnostic(
                    source: ClipboardSourceIdentity(sourceID),
                    mimeType: mimeType,
                    operation: .sourceWriteFailed,
                    message: error.description
                )
            )
        }
    }
}
