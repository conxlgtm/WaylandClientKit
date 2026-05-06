package struct DataOfferID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue offerRawValue: UInt64) {
        rawValue = offerRawValue
    }

    package var description: String {
        "data-offer-\(rawValue)"
    }
}

package struct DataSourceID: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(rawValue sourceRawValue: UInt64) {
        rawValue = sourceRawValue
    }

    package var description: String {
        "data-source-\(rawValue)"
    }
}

package enum DataOfferRole: Equatable, Sendable {
    case selection(seatID: SeatID)
    case dragAndDrop(seatID: SeatID)

    package var seatID: SeatID {
        switch self {
        case .selection(let seatID), .dragAndDrop(let seatID):
            seatID
        }
    }
}

package struct DataOfferSnapshot: Equatable, Sendable {
    package let id: DataOfferID
    package let role: DataOfferRole
    package let mimeTypes: [MIMEType]
}

package struct DataSourceSnapshot: Equatable, Sendable {
    package let id: DataSourceID
    package let seatID: SeatID
    package let mimeTypes: [MIMEType]
}

package struct DataTransferSeatSnapshot: Equatable, Sendable {
    package let seatID: SeatID
    package let hasDataDevice: Bool
    package let selectionOfferID: DataOfferID?
    package let selectionSourceID: DataSourceID?
}

package enum DataTransferAction: Equatable, Sendable {
    case seatAvailable(SeatID)
    case dataDeviceBound(SeatID)
    case seatRemoved(SeatID)
    case offerCreated(id: DataOfferID, role: DataOfferRole)
    case offerMimeType(id: DataOfferID, mimeType: MIMEType)
    case selectionChanged(seatID: SeatID, offerID: DataOfferID?)
    case sourceCreated(id: DataSourceID, seatID: SeatID, mimeTypes: [MIMEType])
    case selectionSourceChanged(seatID: SeatID, sourceID: DataSourceID?)
    case sourceCancelled(DataSourceID)
}

package enum DataTransferEffect: Equatable, Sendable {
    case bindDataDevice(SeatID)
    case releaseDataDevice(SeatID)
    case destroyOffer(DataOfferID)
    case cancelSource(DataSourceID)
    case publishSelectionChanged(seatID: SeatID, offerID: DataOfferID?)
    case publishSourceCancelled(DataSourceID)
}

package struct DataTransferTransitionPlan: Equatable, Sendable {
    package let state: DataTransferState
    package let effects: [DataTransferEffect]
}

package struct DataTransferState: Equatable, Sendable {
    private var seats: [SeatID: SeatState]
    private var offers: [DataOfferID: OfferState]
    private var sources: [DataSourceID: SourceState]

    package init() {
        seats = [:]
        offers = [:]
        sources = [:]
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

        try validateSelectionReferences()
    }

    package var seatSnapshots: [DataTransferSeatSnapshot] {
        seats
            .values
            .sorted { $0.seatID.rawValue < $1.seatID.rawValue }
            .map(\.snapshot)
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        offers
            .values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map(\.snapshot)
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        sources
            .values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map(\.snapshot)
    }

    package func offerSnapshot(_ id: DataOfferID) -> DataOfferSnapshot? {
        offers[id]?.snapshot
    }

    package func sourceSnapshot(_ id: DataSourceID) -> DataSourceSnapshot? {
        sources[id]?.snapshot
    }

    package func seatSnapshot(_ id: SeatID) -> DataTransferSeatSnapshot? {
        seats[id]?.snapshot
    }

    package func reduce(_ action: DataTransferAction) throws -> DataTransferTransitionPlan {
        var next = self
        let effects = try next.apply(action)
        return DataTransferTransitionPlan(state: next, effects: effects)
    }
}

private typealias SeatState = DataTransferSeatState
private typealias OfferState = DataTransferOfferState
private typealias SourceState = DataTransferSourceState

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
        case .sourceCreated(let id, let seatID, let mimeTypes):
            return try applySourceCreated(id: id, seatID: seatID, mimeTypes: mimeTypes)
        case .selectionSourceChanged(let seatID, let sourceID):
            return try applySelectionSourceChanged(seatID: seatID, sourceID: sourceID)
        case .sourceCancelled(let sourceID):
            return applySourceCancelled(sourceID)
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

        seat.hasDataDevice = true
        seats[seatID] = seat
        return []
    }

    private mutating func applySeatRemoved(_ seatID: SeatID) -> [DataTransferEffect] {
        guard let seat = seats.removeValue(forKey: seatID) else {
            return []
        }

        var effects: [DataTransferEffect] = []
        if seat.hasDataDevice {
            effects.append(.releaseDataDevice(seatID))
        }
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)

        for offer in offers.values where offer.role.seatID == seatID {
            appendSelectionOfferCleanup(offer.id, to: &effects)
        }
        for source in sources.values where source.seatID == seatID {
            appendSelectionSourceCleanup(source.id, to: &effects)
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

        if !offer.mimeTypes.contains(mimeType) {
            offer.mimeTypes.append(mimeType)
        }
        offers[id] = offer
        return []
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
        }

        let nextSelection = ClipboardSelectionState.fromRemoteOffer(offerID)
        guard seat.selection != nextSelection else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)
        seat.selection = nextSelection
        seats[seatID] = seat
        effects.append(.publishSelectionChanged(seatID: seatID, offerID: offerID))
        return effects
    }

    private mutating func applySourceCreated(
        id: DataSourceID,
        seatID: SeatID,
        mimeTypes: [MIMEType]
    ) throws -> [DataTransferEffect] {
        guard sources[id] == nil else {
            throw DataTransferError.duplicateSource
        }
        _ = try boundSeat(seatID)

        sources[id] = SourceState(id: id, seatID: seatID, mimeTypes: mimeTypes)
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
        }

        let nextSelection = ClipboardSelectionState.fromOwnedSource(sourceID)
        guard seat.selection != nextSelection else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionCleanup(seat.selection, seatID: seatID, to: &effects)
        seat.selection = nextSelection
        seats[seatID] = seat
        return effects
    }

    private mutating func applySourceCancelled(
        _ sourceID: DataSourceID
    ) -> [DataTransferEffect] {
        guard let source = sources.removeValue(forKey: sourceID) else {
            return []
        }

        if var seat = seats[source.seatID], seat.selection == .ownedSource(sourceID) {
            seat.selection = .none
            seats[source.seatID] = seat
        }

        return [.cancelSource(sourceID), .publishSourceCancelled(sourceID)]
    }

    private func boundSeat(_ seatID: SeatID) throws -> SeatState {
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
            }

            if let sourceID = seat.selection.sourceID {
                guard let source = sources[sourceID], source.seatID == seat.seatID else {
                    throw DataTransferError.unknownSource
                }
            }
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
        guard let sourceID, sources.removeValue(forKey: sourceID) != nil else {
            return
        }

        effects.append(.cancelSource(sourceID))
        effects.append(.publishSourceCancelled(sourceID))
    }

    private mutating func appendSelectionCleanup(
        _ selection: ClipboardSelectionState,
        seatID: SeatID,
        to effects: inout [DataTransferEffect]
    ) {
        switch selection {
        case .none:
            return
        case .remoteOffer(let offerID):
            appendSelectionOfferCleanup(offerID, seatID: seatID, to: &effects)
        case .ownedSource(let sourceID):
            appendSelectionSourceCleanup(sourceID, seatID: seatID, to: &effects)
        }
    }
}
