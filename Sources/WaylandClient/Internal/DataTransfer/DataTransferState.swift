// swiftlint:disable file_length

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
        try validateSelectionReferences()
        try validateDragReferences()
    }

    package var seatSnapshots: [DataTransferSeatSnapshot] {
        seats
            .values
            .sortedByRawValue(\.seatID)
            .map { seat in
                DataTransferSeatSnapshot(
                    seatID: seat.seatID,
                    device: seat.device,
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
            device: seat.device,
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
        case .dataDeviceBound(let seatID):
            return try applyDataDeviceBound(seatID)
        case .seatRemoved(let seatID):
            return applySeatRemoved(seatID)
        case .offerCreated(let id, let role):
            return try applyOfferCreated(id: id, role: role)
        case .offerMimeType(let id, let mimeType):
            return try applyOfferMimeType(id: id, mimeType: mimeType)
        case .selectionChanged(let seatID, let offerID):
            return try applySelectionChanged(seatID: seatID, offerID: offerID)
        case .offerSourceActions, .offerSelectedAction, .dragAccepted,
            .dragActionsRequested, .dragEntered, .dragMotion, .dragLeft, .dragDropped,
            .dragFinished, .dragCancelled:
            return try applyDragAndDrop(action)
        case .sourceCreated(let id, let seatID, let mimeTypes):
            return try applySourceCreated(
                id: id,
                role: .selection(seatID: seatID),
                mimeTypes: mimeTypes
            )
        case .dragSourceCreated, .dragSourceTargetChanged, .dragSourceActionChanged,
            .dragSourceDropPerformed, .dragSourceFinished, .dragSourceInvalidFinished:
            return try applyDragSource(action)
        case .selectionSourceChanged, .sourceCancelled:
            return try applySelectionSource(action)
        }
    }

    private mutating func applySeatAvailable(_ seatID: SeatID) -> [DataTransferEffect] {
        guard seats[seatID] == nil else {
            return []
        }

        seats[seatID] = SeatState(seatID: seatID)
        return [.bindDataDevice(seatID)]
    }

    private mutating func applyDataDeviceBound(_ seatID: SeatID) throws -> [DataTransferEffect] {
        guard var seat = seats[seatID] else {
            throw DataTransferError.unknownSeat(seatID)
        }

        guard !seat.hasDataDevice else {
            return []
        }

        seat.bindDataDevice()
        seats[seatID] = seat
        return []
    }

    private mutating func applySeatRemoved(_ seatID: SeatID) -> [DataTransferEffect] {
        guard let seat = seats.removeValue(forKey: seatID) else {
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
        if seat.hasDataDevice {
            effects.append(.releaseDataDevice(seatID))
        }
        activeDragOffers[seatID] = nil
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)

        for offerID in offerIDsForSeat {
            appendSelectionOfferCleanup(offerID, to: &effects)
        }
        for sourceID in sourceIDsForSeat {
            appendSourceCleanup(sourceID, to: &effects)
        }

        return effects
    }

    private mutating func applyOfferCreated(
        id: DataOfferID,
        role: DataOfferRole
    ) throws -> [DataTransferEffect] {
        guard offers[id] == nil else {
            throw DataTransferError.duplicateOffer
        }
        _ = try boundSeat(role.seatID)

        offers[id] = OfferState(id: id, role: role)
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

        switch offer.role {
        case .selection(let seatID) where seats[seatID]?.selection == .remoteOffer(id):
            return [.publishSelectionChanged(seatID: seatID, offerID: id)]
        case .dragAndDrop(let seatID) where activeDragOffers[seatID] == id:
            return [.publishDragOfferChanged(seatID: seatID, offerID: id)]
        default:
            return []
        }
    }

    private mutating func applySelectionChanged(
        seatID: SeatID,
        offerID: DataOfferID?
    ) throws -> [DataTransferEffect] {
        guard var seat = seats[seatID] else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        if let offerID {
            guard let offer = offers[offerID] else {
                throw DataTransferError.unknownOffer
            }
            guard case .selection(seatID) = offer.role else {
                throw DataTransferError.unknownOffer
            }
            guard offer.snapshot != nil else {
                throw DataTransferError.emptyDataOffer
            }
        }

        let nextSelection = DataSelectionState.fromRemoteOffer(offerID)
        guard seat.selection != nextSelection else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)
        try seat.setSelection(nextSelection)
        seats[seatID] = seat
        effects.append(.publishSelectionChanged(seatID: seatID, offerID: offerID))
        return effects
    }

    private mutating func applySourceCreated(
        id: DataSourceID,
        role: DataSourceRole,
        mimeTypes: [MIMEType]
    ) throws -> [DataTransferEffect] {
        guard sources[id] == nil else {
            throw DataTransferError.duplicateSource
        }
        _ = try boundSeat(role.seatID)

        sources[id] = try SourceState(id: id, role: role, mimeTypes: mimeTypes)
        return []
    }

    private mutating func applySelectionSourceChanged(
        seatID: SeatID,
        sourceID: DataSourceID?
    ) throws -> [DataTransferEffect] {
        guard var seat = seats[seatID] else {
            throw DataTransferError.unknownSeat(seatID)
        }
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }
        if let sourceID {
            guard let source = sources[sourceID] else {
                throw DataTransferError.unknownSource
            }
            guard source.seatID == seatID else {
                throw DataTransferError.unknownSource
            }
            guard case .selection = source.role else {
                throw DataTransferError.unknownSource
            }
        }

        let nextSelection = DataSelectionState.fromOwnedSource(sourceID)
        guard seat.selection != nextSelection else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)
        try seat.setSelection(nextSelection)
        seats[seatID] = seat
        return effects
    }

    private mutating func applySelectionSource(
        _ action: DataTransferAction
    ) throws -> [DataTransferEffect] {
        switch action {
        case .selectionSourceChanged(let seatID, let sourceID):
            return try applySelectionSourceChanged(seatID: seatID, sourceID: sourceID)
        case .sourceCancelled(let sourceID):
            return try applySourceCancelled(sourceID)
        default:
            return []
        }
    }

    private mutating func applySourceCancelled(
        _ sourceID: DataSourceID
    ) throws -> [DataTransferEffect] {
        guard let source = sources.removeValue(forKey: sourceID) else {
            return []
        }

        if case .selection = source.role {
            if var seat = seats[source.seatID], seat.selection == .ownedSource(sourceID) {
                try seat.setSelection(.none)
                seats[source.seatID] = seat
            }
            return [.cancelSource(sourceID), .publishSourceCancelled(sourceID)]
        }

        if case .dragAndDrop = source.role {
            return [.cancelSource(sourceID), .publishDragSourceCancelled(sourceID)]
        }

        return [.cancelSource(sourceID)]
    }

    private mutating func applyDragSource(
        _ action: DataTransferAction
    ) throws -> [DataTransferEffect] {
        switch action {
        case .dragSourceCreated(let id, let seatID, let mimeTypes, let actions):
            return try applySourceCreated(
                id: id,
                role: .dragAndDrop(seatID: seatID, actions: try DragSourceActions(actions)),
                mimeTypes: mimeTypes
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
        guard seat.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }

        return seat
    }

    private func validateSelectionReferences() throws {
        for seat in seats.values {
            if seat.selection.hasAnySelection {
                guard seat.hasDataDevice else {
                    throw DataTransferError.missingDataDevice(seat.seatID)
                }
            }

            if let offerID = seat.selection.offerID {
                guard let offer = offers[offerID],
                    case .selection(seat.seatID) = offer.role
                else {
                    throw DataTransferError.unknownOffer
                }
                guard offer.snapshot != nil else {
                    throw DataTransferError.emptyDataOffer
                }
            }

            if let sourceID = seat.selection.sourceID {
                guard let source = sources[sourceID],
                    source.seatID == seat.seatID,
                    case .selection = source.role
                else {
                    throw DataTransferError.unknownSource
                }
            }
        }
    }

    private func validateDragReferences() throws {
        var referencedOfferIDs: Set<DataOfferID> = []
        for (seatID, offerID) in activeDragOffers {
            guard let seat = seats[seatID], seat.hasDataDevice else {
                throw DataTransferError.missingDataDevice(seatID)
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
            _ = try boundSeat(offer.role.seatID)
        }

        for source in sources.values {
            _ = try boundSeat(source.seatID)
        }
    }

    private mutating func appendSelectionOfferCleanup(
        _ offerID: DataOfferID?,
        seatID: SeatID,
        to effects: inout [DataTransferEffect]
    ) {
        guard let offerID, offers[offerID]?.role.seatID == seatID else {
            return
        }

        appendSelectionOfferCleanup(offerID, to: &effects)
    }

    private mutating func appendSelectionOfferCleanup(
        _ offerID: DataOfferID?,
        to effects: inout [DataTransferEffect]
    ) {
        guard let offerID, offers.removeValue(forKey: offerID) != nil else {
            return
        }

        effects.append(.destroyOffer(offerID))
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

    private mutating func appendSelectionSourceCleanup(
        _ sourceID: DataSourceID?,
        seatID: SeatID,
        to effects: inout [DataTransferEffect]
    ) {
        guard let sourceID, sources[sourceID]?.seatID == seatID else {
            return
        }

        appendSelectionSourceCleanup(sourceID, to: &effects)
    }

    private mutating func appendSelectionSourceCleanup(
        _ sourceID: DataSourceID?,
        to effects: inout [DataTransferEffect]
    ) {
        guard let sourceID,
            let source = sources[sourceID],
            case .selection = source.role
        else {
            return
        }

        _ = sources.removeValue(forKey: sourceID)
        effects.append(.cancelSource(sourceID))
        effects.append(.publishSourceCancelled(sourceID))
    }

    private mutating func appendSourceCleanup(
        _ sourceID: DataSourceID?,
        to effects: inout [DataTransferEffect]
    ) {
        guard let sourceID, let source = sources.removeValue(forKey: sourceID) else {
            return
        }

        effects.append(.cancelSource(sourceID))
        switch source.role {
        case .selection:
            effects.append(.publishSourceCancelled(sourceID))
        case .dragAndDrop:
            effects.append(.publishDragSourceCancelled(sourceID))
        }
    }

    private mutating func appendSelectionCleanup(
        _ selection: DataSelectionState,
        seatID: SeatID,
        to effects: inout [DataTransferEffect]
    ) {
        appendSelectionOfferCleanup(selection.offerID, seatID: seatID, to: &effects)
        appendSelectionSourceCleanup(selection.sourceID, seatID: seatID, to: &effects)
    }
}
