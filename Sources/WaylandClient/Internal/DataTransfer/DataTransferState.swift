import WaylandRaw

package struct DataTransferState: Equatable, Sendable {
    private var seats: [SeatID: SeatState]
    var offers: [DataOfferID: OfferState]
    private var sources: [DataSourceID: SourceState]
    var activeDragOffers: [SeatID: DataOfferID]

    package init() {
        seats = [:]
        offers = [:]
        sources = [:]
        activeDragOffers = [:]
    }

    package init(
        seats initialSeats: [SeatID: DataTransferSeatSnapshot],
        offers initialOffers: [DataOfferID: DataOfferSnapshot] = [:],
        sources initialSources: [DataSourceID: DataSourceSnapshot] = [:]
    ) throws {
        seats = [:]
        for (seatID, snapshot) in initialSeats {
            guard seatID == snapshot.seatID else {
                throw DataTransferError.unknownSeat(seatID)
            }
            seats[seatID] = try SeatState(snapshot)
        }

        activeDragOffers = initialSeats.reduce(into: [:]) { partial, element in
            let (seatID, snapshot) = element
            if let offerID = snapshot.dragAndDropOfferID {
                partial[seatID] = offerID
            }
        }

        offers = [:]
        for (offerID, snapshot) in initialOffers {
            guard offerID == snapshot.id else {
                throw DataTransferError.unknownOffer
            }
            offers[offerID] = OfferState(snapshot)
        }

        sources = [:]
        for (sourceID, snapshot) in initialSources {
            guard sourceID == snapshot.id else {
                throw DataTransferError.unknownSource
            }
            sources[sourceID] = SourceState(snapshot)
        }

        try validateOfferAndSourceSeats()
        try validateDragReferences()
    }

    package var seatSnapshots: [DataTransferSeatSnapshot] {
        seats
            .values
            .sortedByRawValue(\.seatID)
            .map { seat in
                DataTransferSeatSnapshot(
                    seatID: seat.seatID,
                    device: .unbound,
                    dragAndDropOfferID: activeDragOffers[seat.seatID]
                )
            }
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        offers
            .values
            .sortedByRawValue(\.id)
            .compactMap(\.snapshot)
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        sources
            .values
            .sortedByRawValue(\.id)
            .map(\.snapshot)
    }

    package func offerSnapshot(_ id: DataOfferID) -> DataOfferSnapshot? {
        offers[id]?.snapshot
    }

    package func sourceSnapshot(_ id: DataSourceID) -> DataSourceSnapshot? {
        sources[id]?.snapshot
    }

    package func seatSnapshot(_ id: SeatID) -> DataTransferSeatSnapshot? {
        guard let seat = seats[id] else {
            return nil
        }

        return DataTransferSeatSnapshot(
            seatID: seat.seatID,
            device: .unbound,
            dragAndDropOfferID: activeDragOffers[seat.seatID]
        )
    }

    package func reduce(_ action: DataTransferAction) throws -> DataTransferTransitionPlan {
        var next = self
        let effects = try next.apply(action)
        return DataTransferTransitionPlan(state: next, effects: effects)
    }

    package func reduce(_ actions: [DataTransferAction]) throws -> DataTransferTransitionPlan {
        var next = self
        var effects: [DataTransferEffect] = []
        for action in actions {
            effects.append(contentsOf: try next.apply(action))
        }
        return DataTransferTransitionPlan(state: next, effects: effects)
    }
}

typealias SeatState = DataTransferSeatState
typealias OfferState = DataTransferOfferState
typealias SourceState = DataTransferSourceState

extension DataTransferState {
    private mutating func apply(_ action: DataTransferAction) throws -> [DataTransferEffect] {
        switch action {
        case .seatAvailable(let seatID):
            return applySeatAvailable(seatID)
        case .seatRemoved(let seatID):
            return applySeatRemoved(seatID)
        case .dragOfferCreated(let id, let seatID):
            return try applyDragOfferCreated(id: id, seatID: seatID)
        case .offerMimeType(let id, let mimeType):
            return try applyOfferMimeType(id: id, mimeType: mimeType)
        case .offerSourceActions, .offerSelectedAction, .dragAccepted,
            .dragActionsRequested, .dragEntered, .dragMotion, .dragLeft, .dragDropped,
            .dragFinished, .dragCancelled:
            return try applyDragAndDrop(action)
        case .dragSourceCreated, .dragSourceTargetChanged, .dragSourceActionChanged,
            .dragSourceDropPerformed, .dragSourceFinished, .dragSourceInvalidFinished:
            return try applyDragSource(action)
        case .sourceCancelled(let sourceID):
            return applySourceCancelled(sourceID)
        }
    }

    private mutating func applySeatAvailable(_ seatID: SeatID) -> [DataTransferEffect] {
        guard seats[seatID] == nil else {
            return []
        }

        seats[seatID] = SeatState(seatID: seatID)
        return []
    }

    private mutating func applySeatRemoved(_ seatID: SeatID) -> [DataTransferEffect] {
        guard seats.removeValue(forKey: seatID) != nil else {
            return []
        }

        let offerIDsForSeat = offers.values
            .filter { $0.role.seatID == seatID }
            .map(\.id)
            .sortedByRawValue()
        let sourceIDsForSeat = sources.values
            .filter { $0.seatID == seatID }
            .map(\.id)
            .sortedByRawValue()

        var effects: [DataTransferEffect] = []
        activeDragOffers[seatID] = nil

        for offerID in offerIDsForSeat {
            appendDragOfferCleanup(offerID, to: &effects)
        }
        for sourceID in sourceIDsForSeat {
            appendSourceCleanup(sourceID, to: &effects)
        }

        return effects
    }

    private mutating func applyDragOfferCreated(
        id: DataOfferID,
        seatID: SeatID
    ) throws -> [DataTransferEffect] {
        guard offers[id] == nil else {
            throw DataTransferError.duplicateOffer
        }
        _ = try boundSeat(seatID)

        offers[id] = OfferState(id: id, role: .dragAndDrop(seatID: seatID))
        return []
    }

    private mutating func applyOfferMimeType(
        id: DataOfferID,
        mimeType: MIMEType
    ) throws -> [DataTransferEffect] {
        guard var offer = offers[id] else {
            throw DataTransferError.unknownOffer
        }

        let wasSelectable = offer.snapshot != nil
        let didChange = try offer.appendMIMETypeIfNew(mimeType)
        offers[id] = offer

        guard didChange, wasSelectable else {
            return []
        }

        if case .dragAndDrop(let seatID) = offer.role, activeDragOffers[seatID] == id {
            return [.publishDragOfferChanged(seatID: seatID, offerID: id)]
        }
        return []
    }

    private mutating func applyDragSourceCreated(
        id: DataSourceID,
        seatID: SeatID,
        mimeTypes: [MIMEType],
        actions: DragActionSet
    ) throws -> [DataTransferEffect] {
        guard sources[id] == nil else {
            throw DataTransferError.duplicateSource
        }
        _ = try boundSeat(seatID)

        sources[id] = try SourceState(
            id: id,
            role: .dragAndDrop(seatID: seatID, actions: try DragSourceActions(actions)),
            mimeTypes: mimeTypes
        )
        return []
    }

    private mutating func applySourceCancelled(
        _ sourceID: DataSourceID
    ) -> [DataTransferEffect] {
        guard sources.removeValue(forKey: sourceID) != nil else {
            return []
        }
        return [.cancelSource(sourceID), .publishDragSourceCancelled(sourceID)]
    }

    private mutating func applyDragSource(
        _ action: DataTransferAction
    ) throws -> [DataTransferEffect] {
        switch action {
        case .dragSourceCreated(let id, let seatID, let mimeTypes, let actions):
            return try applyDragSourceCreated(
                id: id,
                seatID: seatID,
                mimeTypes: mimeTypes,
                actions: actions
            )
        case .dragSourceTargetChanged(let id, let mimeType):
            return try applyDragSourceTargetChanged(id: id, mimeType: mimeType)
        case .dragSourceActionChanged(let id, let action):
            return try applyDragSourceActionChanged(id: id, action: action)
        case .dragSourceDropPerformed(let id):
            return try applyDragSourceDropPerformed(id)
        case .dragSourceFinished(let id):
            return try applyDragSourceFinished(id)
        case .dragSourceInvalidFinished(let id):
            return try applyDragSourceInvalidFinished(id)
        default:
            return []
        }
    }

    private func requireDragSource(_ sourceID: DataSourceID) throws -> SourceState {
        guard let source = sources[sourceID], case .dragAndDrop = source.role else {
            throw DataTransferError.unknownDragSourceIdentity(sourceID.dragIdentity)
        }

        return source
    }

    private func applyDragSourceTargetChanged(
        id sourceID: DataSourceID,
        mimeType: MIMEType?
    ) throws -> [DataTransferEffect] {
        _ = try requireDragSource(sourceID)
        return [.publishDragSourceTargetChanged(id: sourceID, mimeType: mimeType)]
    }

    private mutating func applyDragSourceActionChanged(
        id sourceID: DataSourceID,
        action: DragAction
    ) throws -> [DataTransferEffect] {
        var source = try requireDragSource(sourceID)
        try source.setSelectedDragAction(action)
        sources[sourceID] = source
        return [.publishDragSourceActionChanged(id: sourceID, action: action)]
    }

    private mutating func applyDragSourceDropPerformed(
        _ sourceID: DataSourceID
    ) throws -> [DataTransferEffect] {
        var source = try requireDragSource(sourceID)
        guard try source.markDragDropped() else {
            return []
        }

        sources[sourceID] = source
        return [.publishDragSourceDropPerformed(sourceID)]
    }

    private mutating func applyDragSourceFinished(
        _ sourceID: DataSourceID
    ) throws -> [DataTransferEffect] {
        let source = try requireDragSource(sourceID)
        let finalAction = try source.finishedDragAction()
        _ = sources.removeValue(forKey: sourceID)
        return [
            .destroySource(sourceID),
            .publishDragSourceFinished(id: sourceID, finalAction: finalAction),
        ]
    }

    private mutating func applyDragSourceInvalidFinished(
        _ sourceID: DataSourceID
    ) throws -> [DataTransferEffect] {
        _ = try requireDragSource(sourceID)
        _ = sources.removeValue(forKey: sourceID)
        return [.cancelSource(sourceID)]
    }

    func boundSeat(_ seatID: SeatID) throws -> SeatState {
        guard let seat = seats[seatID] else {
            throw DataTransferError.unknownSeat(seatID)
        }

        return seat
    }

    private func validateDragReferences() throws {
        var referencedOfferIDs: Set<DataOfferID> = []
        for (seatID, offerID) in activeDragOffers {
            guard seats[seatID] != nil else {
                throw DataTransferError.unknownSeat(seatID)
            }
            guard let offer = offers[offerID],
                case .dragAndDrop(seatID) = offer.role
            else {
                throw DataTransferError.unknownOffer
            }
            guard offer.snapshot != nil else {
                throw DataTransferError.emptyDataOffer
            }
            guard offer.dragAndDrop?.enterSerial != nil else {
                throw DataTransferError.dragOfferNotActive(offerID.dragIdentity)
            }
            referencedOfferIDs.insert(offerID)
        }

        for offer in offers.values {
            guard case .dragAndDrop = offer.role else {
                continue
            }
            guard referencedOfferIDs.contains(offer.id) else {
                throw DataTransferError.dragOfferNotActive(offer.id.dragIdentity)
            }
        }
    }

    private func validateOfferAndSourceSeats() throws {
        for offer in offers.values {
            guard case .dragAndDrop = offer.role else {
                throw DataTransferError.unknownOffer
            }
            _ = try boundSeat(offer.role.seatID)
        }

        for source in sources.values {
            guard case .dragAndDrop = source.role else {
                throw DataTransferError.unknownSource
            }
            _ = try boundSeat(source.seatID)
        }
    }

    mutating func appendDragOfferCleanup(
        _ offerID: DataOfferID?,
        to effects: inout [DataTransferEffect]
    ) {
        guard let offerID, offers.removeValue(forKey: offerID) != nil else {
            return
        }

        effects.append(.destroyOffer(offerID))
    }

    private mutating func appendSourceCleanup(
        _ sourceID: DataSourceID?,
        to effects: inout [DataTransferEffect]
    ) {
        guard let sourceID, sources.removeValue(forKey: sourceID) != nil else {
            return
        }

        effects.append(.cancelSource(sourceID))
        effects.append(.publishDragSourceCancelled(sourceID))
    }
}
