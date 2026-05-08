import WaylandRaw

package enum DataTransferGlobalBindingState: Equatable, Sendable {
    case unbound
    case boundWithDataDeviceManager
    case boundWithoutDataDeviceManager
}

package enum PrimarySelectionGlobalBindingState: Equatable, Sendable {
    case unbound
    case boundWithPrimarySelectionDeviceManager
    case boundWithoutPrimarySelectionDeviceManager
}

package enum DataTransferProcessingRequirement: Equatable, Sendable {
    case optional
    case requiresDataDeviceManager
}

package enum PrimarySelectionProcessingRequirement: Equatable, Sendable {
    case optional
    case requiresPrimarySelectionDeviceManager
}

package enum DataTransferGlobalProcessingDecision: Equatable, Sendable {
    case skip
    case bindRequiredGlobals
    case synchronizeSeats
}

package enum DataTransferGlobalProcessingOutcome: Equatable, Sendable {
    case skipped
    case synchronized
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

package struct PrimarySelectionGlobalSnapshot: Equatable, Sendable {
    package let bindingState: PrimarySelectionGlobalBindingState
    package let seatIDs: [SeatID]

    package init(
        bindingState snapshotBindingState: PrimarySelectionGlobalBindingState,
        seatIDs snapshotSeatIDs: [SeatID]
    ) {
        bindingState = snapshotBindingState
        seatIDs = snapshotSeatIDs
    }
}

package protocol DataTransferGlobalProviding {
    var currentDataTransferGlobalSnapshot: DataTransferGlobalSnapshot? { get }
    var currentPrimarySelectionGlobalSnapshot: PrimarySelectionGlobalSnapshot? { get }

    func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot
    func bindRequiredPrimarySelectionGlobals() throws -> PrimarySelectionGlobalSnapshot
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

    package var currentPrimarySelectionGlobalSnapshot: PrimarySelectionGlobalSnapshot? {
        guard let globals = boundGlobals else {
            return nil
        }

        return DisplaySession.primarySelectionGlobalSnapshot(for: globals)
    }

    package func bindRequiredPrimarySelectionGlobals() throws -> PrimarySelectionGlobalSnapshot {
        try DisplaySession.primarySelectionGlobalSnapshot(for: bindRequiredGlobals())
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
        try processClipboardDataTransferState()
        return try dataTransferManager.selectionOffer(for: seatID)
    }

    package func primarySelectionOfferOnOwnerThread(
        for seatID: SeatID
    ) throws -> DataOfferSnapshot? {
        connection.preconditionIsOwnerThread()
        try processPrimarySelectionState(requirement: .requiresPrimarySelectionDeviceManager)
        return try primarySelectionController.offer(for: seatID)
    }

    package func receiveClipboardOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func receivePrimarySelectionOfferOnOwnerThread(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        connection.preconditionIsOwnerThread()
        try processPrimarySelectionState(requirement: .requiresPrimarySelectionDeviceManager)
        return try primarySelectionController.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func setClipboardOnOwnerThread(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        return try dataTransferManager.setSelectionSource(
            seatID: seatID,
            payloads: configuration.payloadSet,
            serial: serial
        )
    }

    package func setPrimarySelectionOnOwnerThread(
        _ configuration: PrimarySelectionSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        connection.preconditionIsOwnerThread()
        try processPrimarySelectionState(requirement: .requiresPrimarySelectionDeviceManager)
        return try primarySelectionController.setSelectionSource(
            seatID: seatID,
            payloads: configuration.payloadSet,
            serial: serial
        )
    }

    package func clearClipboardOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func clearPrimarySelectionOnOwnerThread(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processPrimarySelectionState(requirement: .requiresPrimarySelectionDeviceManager)
        try primarySelectionController.clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func clearClipboardOnOwnerThread(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processClipboardDataTransferState()
        try dataTransferManager.clearSelectionSource(
            id: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func clearPrimarySelectionOnOwnerThread(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try processPrimarySelectionState(requirement: .requiresPrimarySelectionDeviceManager)
        try primarySelectionController.clearSelectionSource(
            id: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func processInputDataTransferState() throws {
        try processDataTransferState(requirement: .optional)
        try processPrimarySelectionState(requirement: .optional)
    }

    private func processClipboardDataTransferState() throws {
        try processDataTransferState(requirement: .requiresDataDeviceManager)
    }

    private func processPrimarySelectionState(
        requirement: PrimarySelectionProcessingRequirement
    ) throws {
        collectDataTransferSourceWriteResults()
        try primarySelectionController.throwPendingCallbackErrorIfAny()
        let outcome = try Self.processPrimarySelectionGlobals(
            requirement: requirement,
            provider: dataTransferGlobalProvider
        ) { seatIDs in
            try primarySelectionController.synchronizeSeats(seatIDs)
        }
        guard outcome == .synchronized else {
            return
        }

        try submitPendingPrimarySelectionSourceWrites()
    }

    private func processDataTransferState(
        requirement: DataTransferProcessingRequirement
    ) throws {
        collectDataTransferSourceWriteResults()
        try dataTransferManager.throwPendingCallbackErrorIfAny()
        try Self.processDataTransferGlobalEffects(
            requirement: requirement,
            provider: dataTransferGlobalProvider,
            synchronizeSeats: { seatIDs in
                try dataTransferManager.synchronizeSeats(seatIDs)
            },
            submitSourceWrites: {
                try submitPendingDataTransferSourceWrites()
            }
        )
    }

    package static func processDataTransferGlobalEffects(
        requirement: DataTransferProcessingRequirement,
        provider: any DataTransferGlobalProviding,
        synchronizeSeats: ([SeatID]) throws -> Void,
        submitSourceWrites: () throws -> Void
    ) throws {
        let outcome = try processDataTransferGlobals(
            requirement: requirement,
            provider: provider,
            synchronizeSeats: synchronizeSeats
        )
        guard outcome == .synchronized else {
            return
        }

        try submitSourceWrites()
    }

    package static func processDataTransferGlobals(
        requirement: DataTransferProcessingRequirement,
        provider: any DataTransferGlobalProviding,
        synchronizeSeats: ([SeatID]) throws -> Void
    ) throws -> DataTransferGlobalProcessingOutcome {
        let decision = try Self.dataTransferGlobalProcessingDecision(
            state: provider.currentDataTransferGlobalSnapshot?.bindingState ?? .unbound,
            requirement: requirement
        )
        let snapshot: DataTransferGlobalSnapshot
        switch decision {
        case .skip:
            return .skipped
        case .bindRequiredGlobals:
            snapshot = try provider.bindRequiredDataTransferGlobals()
            let postBindDecision = try Self.dataTransferGlobalProcessingDecision(
                state: snapshot.bindingState,
                requirement: requirement
            )
            guard postBindDecision == .synchronizeSeats else {
                return .skipped
            }
        case .synchronizeSeats:
            guard let currentSnapshot = provider.currentDataTransferGlobalSnapshot else {
                throw DataTransferError.unavailable
            }

            snapshot = currentSnapshot
        }

        try synchronizeSeats(snapshot.seatIDs)
        return .synchronized
    }

    package static func processPrimarySelectionGlobals(
        requirement: PrimarySelectionProcessingRequirement,
        provider: any DataTransferGlobalProviding,
        synchronizeSeats: ([SeatID]) throws -> Void
    ) throws -> DataTransferGlobalProcessingOutcome {
        let decision = try Self.primarySelectionGlobalProcessingDecision(
            state: provider.currentPrimarySelectionGlobalSnapshot?.bindingState ?? .unbound,
            requirement: requirement
        )
        let snapshot: PrimarySelectionGlobalSnapshot
        switch decision {
        case .skip:
            return .skipped
        case .bindRequiredGlobals:
            snapshot = try provider.bindRequiredPrimarySelectionGlobals()
            let postBindDecision = try Self.primarySelectionGlobalProcessingDecision(
                state: snapshot.bindingState,
                requirement: requirement
            )
            guard postBindDecision == .synchronizeSeats else {
                return .skipped
            }
        case .synchronizeSeats:
            guard let currentSnapshot = provider.currentPrimarySelectionGlobalSnapshot else {
                throw DataTransferError.unavailable
            }

            snapshot = currentSnapshot
        }

        try synchronizeSeats(snapshot.seatIDs)
        return .synchronized
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

    package static func primarySelectionGlobalProcessingDecision(
        state: PrimarySelectionGlobalBindingState,
        requirement: PrimarySelectionProcessingRequirement
    ) throws -> DataTransferGlobalProcessingDecision {
        switch (state, requirement) {
        case (.unbound, .optional):
            .skip
        case (.unbound, .requiresPrimarySelectionDeviceManager):
            .bindRequiredGlobals
        case (.boundWithPrimarySelectionDeviceManager, _):
            .synchronizeSeats
        case (.boundWithoutPrimarySelectionDeviceManager, .optional):
            .skip
        case (.boundWithoutPrimarySelectionDeviceManager, .requiresPrimarySelectionDeviceManager):
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

    package static func primarySelectionGlobalSnapshot(
        for globals: BoundGlobals
    ) -> PrimarySelectionGlobalSnapshot {
        let seatIDs = globals.seatRegistry.seats.map { SeatID(rawValue: $0.id.rawValue) }

        switch globals.extensions.primarySelectionDeviceManager {
        case .bound:
            return PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithPrimarySelectionDeviceManager,
                seatIDs: seatIDs
            )
        case .missing:
            return PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithoutPrimarySelectionDeviceManager,
                seatIDs: seatIDs
            )
        }
    }

    private func submitPendingDataTransferSourceWrites() throws {
        let jobs = try dataTransferManager.drainSourceWriteJobs()
        dataTransferSourceWriter.submit(jobs)
    }

    private func submitPendingPrimarySelectionSourceWrites() throws {
        let jobs = try primarySelectionController.drainSourceWriteJobs()
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
        guard case .failed(let source, let mimeType, let error) = result else {
            return nil
        }

        return DataTransferDiagnostic(
            source: source.diagnosticSource,
            mimeType: mimeType,
            operation: .sourceWriteFailed,
            error: error
        )
    }
}
