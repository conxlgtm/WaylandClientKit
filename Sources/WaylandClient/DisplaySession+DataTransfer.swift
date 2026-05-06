import WaylandRaw

package enum DataTransferGlobalBindingState: Equatable, Sendable {
    case unbound
    case bound(hasDataDeviceManager: Bool)
}

package enum DataTransferGlobalProcessingDecision: Equatable, Sendable {
    case skip
    case bindRequiredGlobals
    case synchronizeSeats
}

extension DisplaySession {
    package func drainDataTransferDiagnosticsOnOwnerThread() -> [DataTransferDiagnostic] {
        connection.preconditionIsOwnerThread()
        collectDataTransferSourceWriteResults()
        defer { pendingDataTransferDiagnostics.removeAll(keepingCapacity: true) }
        return pendingDataTransferDiagnostics
    }

    package func clipboardOfferOnOwnerThread(for seatID: SeatID) throws -> DataOfferSnapshot? {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requiresDataDeviceManager: true)
        return try dataTransferManager.selectionOffer(for: seatID)
    }

    package func receiveClipboardOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requiresDataDeviceManager: true)
        return try dataTransferManager.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func setClipboardOnOwnerThread(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requiresDataDeviceManager: true)
        return try dataTransferManager.setSelectionSource(
            seatID: seatID,
            mimeTypes: configuration.mimeTypes,
            serial: serial,
            dataProvider: configuration.dataProvider
        )
    }

    package func clearClipboardOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requiresDataDeviceManager: true)
        try dataTransferManager.clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func clearClipboardOnOwnerThread(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requiresDataDeviceManager: true)
        try dataTransferManager.clearSelectionSource(
            id: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func processDataTransferState(
        requiresDataDeviceManager: Bool = false
    ) throws {
        collectDataTransferSourceWriteResults()
        try dataTransferManager.throwPendingCallbackErrorIfAny()

        let decision = try Self.dataTransferGlobalProcessingDecision(
            state: dataTransferGlobalBindingState,
            requiresDataDeviceManager: requiresDataDeviceManager
        )
        let globals: BoundGlobals
        switch decision {
        case .skip:
            return
        case .bindRequiredGlobals:
            globals = try connection.bindRequiredGlobals()
            let postBindDecision = try Self.dataTransferGlobalProcessingDecision(
                state: Self.dataTransferGlobalBindingState(for: globals),
                requiresDataDeviceManager: requiresDataDeviceManager
            )
            guard postBindDecision == .synchronizeSeats else {
                return
            }
        case .synchronizeSeats:
            globals = try requireBoundGlobalsForDataTransferProcessing()
        }

        try dataTransferManager.synchronizeSeats(
            globals.seatRegistry.seats.map { SeatID(rawValue: $0.id.rawValue) }
        )
        try submitPendingDataTransferSourceWrites()
    }

    package static func dataTransferGlobalProcessingDecision(
        state: DataTransferGlobalBindingState,
        requiresDataDeviceManager: Bool
    ) throws -> DataTransferGlobalProcessingDecision {
        switch (state, requiresDataDeviceManager) {
        case (.unbound, false):
            .skip
        case (.unbound, true):
            .bindRequiredGlobals
        case (.bound(hasDataDeviceManager: true), _):
            .synchronizeSeats
        case (.bound(hasDataDeviceManager: false), false):
            .skip
        case (.bound(hasDataDeviceManager: false), true):
            throw DataTransferError.unavailable
        }
    }

    private var dataTransferGlobalBindingState: DataTransferGlobalBindingState {
        guard let globals = connection.boundGlobals else {
            return .unbound
        }

        return Self.dataTransferGlobalBindingState(for: globals)
    }

    private static func dataTransferGlobalBindingState(
        for globals: BoundGlobals
    ) -> DataTransferGlobalBindingState {
        switch globals.extensions.dataDeviceManager {
        case .bound:
            .bound(hasDataDeviceManager: true)
        case .missing:
            .bound(hasDataDeviceManager: false)
        }
    }

    private func requireBoundGlobalsForDataTransferProcessing() throws -> BoundGlobals {
        guard let globals = connection.boundGlobals else {
            throw DataTransferError.unavailable
        }

        return globals
    }

    private func submitPendingDataTransferSourceWrites() throws {
        let jobs = try dataTransferManager.drainSourceWriteJobs()
        dataTransferSourceWriter.submit(jobs)
    }

    private func collectDataTransferSourceWriteResults() {
        for result in dataTransferSourceWriter.drainResults() {
            guard let diagnostic = Self.dataTransferDiagnostic(from: result) else {
                continue
            }

            pendingDataTransferDiagnostics.append(diagnostic)
        }
    }

    package static func dataTransferDiagnostic(
        from result: DataTransferSourceWriteResult
    ) -> DataTransferDiagnostic? {
        guard case .failed(let sourceID, let mimeType, let error) = result else {
            return nil
        }

        return DataTransferDiagnostic(
            source: ClipboardSourceIdentity(sourceID),
            mimeType: mimeType,
            operation: .sourceWriteFailed,
            message: error.description
        )
    }
}
