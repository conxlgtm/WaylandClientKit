import WaylandRaw

package enum DataTransferGlobalBindingState: Equatable, Sendable {
    case unbound
    case boundWithDataDeviceManager
    case boundWithoutDataDeviceManager
}

package enum DataTransferProcessingRequirement: Equatable, Sendable {
    case optional
    case requiresDataDeviceManager
}

package enum DataTransferGlobalProcessingDecision: Equatable, Sendable {
    case skip
    case bindRequiredGlobals
    case synchronizeSeats
}

package struct DataTransferGlobalSnapshot: Equatable, Sendable {
    package let bindingState: DataTransferGlobalBindingState
    package let seatIDs: [SeatID]

    package init(
        bindingState snapshotBindingState: DataTransferGlobalBindingState,
        seatIDs snapshotSeatIDs: [SeatID]
    ) {
        bindingState = snapshotBindingState
        seatIDs = snapshotSeatIDs
    }
}

package protocol DataTransferGlobalProviding {
    var currentDataTransferGlobalSnapshot: DataTransferGlobalSnapshot? { get }

    func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot
}

extension RawDisplayConnection: DataTransferGlobalProviding {
    package var currentDataTransferGlobalSnapshot: DataTransferGlobalSnapshot? {
        guard let globals = boundGlobals else {
            return nil
        }

        return DisplaySession.dataTransferGlobalSnapshot(for: globals)
    }

    package func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot {
        try DisplaySession.dataTransferGlobalSnapshot(for: bindRequiredGlobals())
    }
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
        try processDataTransferState(requirement: .requiresDataDeviceManager)
        return try dataTransferManager.selectionOffer(for: seatID)
    }

    package func receiveClipboardOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requirement: .requiresDataDeviceManager)
        return try dataTransferManager.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func setClipboardOnOwnerThread(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requirement: .requiresDataDeviceManager)
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
        try processDataTransferState(requirement: .requiresDataDeviceManager)
        try dataTransferManager.clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func clearClipboardOnOwnerThread(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processDataTransferState(requirement: .requiresDataDeviceManager)
        try dataTransferManager.clearSelectionSource(
            id: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func processDataTransferState(
        requirement: DataTransferProcessingRequirement
    ) throws {
        collectDataTransferSourceWriteResults()
        try dataTransferManager.throwPendingCallbackErrorIfAny()
        try Self.processDataTransferGlobals(
            requirement: requirement,
            provider: dataTransferGlobalProvider
        ) { seatIDs in
            try dataTransferManager.synchronizeSeats(seatIDs)
        }
        try submitPendingDataTransferSourceWrites()
    }

    package static func processDataTransferGlobals(
        requirement: DataTransferProcessingRequirement,
        provider: any DataTransferGlobalProviding,
        synchronizeSeats: ([SeatID]) throws -> Void
    ) throws {
        let decision = try Self.dataTransferGlobalProcessingDecision(
            state: provider.currentDataTransferGlobalSnapshot?.bindingState ?? .unbound,
            requirement: requirement
        )
        let snapshot: DataTransferGlobalSnapshot
        switch decision {
        case .skip:
            return
        case .bindRequiredGlobals:
            snapshot = try provider.bindRequiredDataTransferGlobals()
            let postBindDecision = try Self.dataTransferGlobalProcessingDecision(
                state: snapshot.bindingState,
                requirement: requirement
            )
            guard postBindDecision == .synchronizeSeats else {
                return
            }
        case .synchronizeSeats:
            guard let currentSnapshot = provider.currentDataTransferGlobalSnapshot else {
                throw DataTransferError.unavailable
            }

            snapshot = currentSnapshot
        }

        try synchronizeSeats(snapshot.seatIDs)
    }

    package static func dataTransferGlobalProcessingDecision(
        state: DataTransferGlobalBindingState,
        requirement: DataTransferProcessingRequirement
    ) throws -> DataTransferGlobalProcessingDecision {
        switch (state, requirement) {
        case (.unbound, .optional):
            .skip
        case (.unbound, .requiresDataDeviceManager):
            .bindRequiredGlobals
        case (.boundWithDataDeviceManager, _):
            .synchronizeSeats
        case (.boundWithoutDataDeviceManager, .optional):
            .skip
        case (.boundWithoutDataDeviceManager, .requiresDataDeviceManager):
            throw DataTransferError.unavailable
        }
    }

    package static func dataTransferGlobalSnapshot(
        for globals: BoundGlobals
    ) -> DataTransferGlobalSnapshot {
        let seatIDs = globals.seatRegistry.seats.map { SeatID(rawValue: $0.id.rawValue) }

        switch globals.extensions.dataDeviceManager {
        case .bound:
            return DataTransferGlobalSnapshot(
                bindingState: .boundWithDataDeviceManager,
                seatIDs: seatIDs
            )
        case .missing:
            return DataTransferGlobalSnapshot(
                bindingState: .boundWithoutDataDeviceManager,
                seatIDs: seatIDs
            )
        }
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
