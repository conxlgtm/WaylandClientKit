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

    package init(
        seats initialSeats: [SeatID: DataTransferSeatSnapshot] = [:],
        offers initialOffers: [DataOfferID: DataOfferSnapshot] = [:],
        sources initialSources: [DataSourceID: DataSourceSnapshot] = [:]
    ) {
        seats = initialSeats.mapValues(SeatState.init)
        offers = initialOffers.mapValues(OfferState.init)
        sources = initialSources.mapValues(SourceState.init)
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
        appendSelectionOfferCleanup(seat.selectionOfferID, to: &effects)
        appendSelectionSourceCleanup(seat.selectionSourceID, to: &effects)

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
        guard seats[role.seatID] != nil else {
            throw DataTransferError.unknownSeat(role.seatID)
        }

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
        if let offerID, offers[offerID] == nil {
            throw DataTransferError.unknownOffer
        }

        guard seat.selectionOfferID != offerID else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionOfferCleanup(seat.selectionOfferID, to: &effects)
        seat.selectionOfferID = offerID
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
        guard seats[seatID] != nil else {
            throw DataTransferError.unknownSeat(seatID)
        }

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
        if let sourceID, sources[sourceID] == nil {
            throw DataTransferError.unknownSource
        }

        guard seat.selectionSourceID != sourceID else {
            return []
        }

        var effects: [DataTransferEffect] = []
        appendSelectionSourceCleanup(seat.selectionSourceID, to: &effects)
        seat.selectionSourceID = sourceID
        seats[seatID] = seat
        return effects
    }

    private mutating func applySourceCancelled(
        _ sourceID: DataSourceID
    ) -> [DataTransferEffect] {
        guard let source = sources.removeValue(forKey: sourceID) else {
            return []
        }

        if var seat = seats[source.seatID], seat.selectionSourceID == sourceID {
            seat.selectionSourceID = nil
            seats[source.seatID] = seat
        }

        return [.cancelSource(sourceID), .publishSourceCancelled(sourceID)]
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
        to effects: inout [DataTransferEffect]
    ) {
        guard let sourceID, sources.removeValue(forKey: sourceID) != nil else {
            return
        }

        effects.append(.cancelSource(sourceID))
    }
}

private struct SeatState: Equatable, Sendable {
    var seatID: SeatID
    var hasDataDevice: Bool
    var selectionOfferID: DataOfferID?
    var selectionSourceID: DataSourceID?

    init(
        seatID stateSeatID: SeatID,
        hasDataDevice stateHasDataDevice: Bool = false,
        selectionOfferID stateSelectionOfferID: DataOfferID? = nil,
        selectionSourceID stateSelectionSourceID: DataSourceID? = nil
    ) {
        seatID = stateSeatID
        hasDataDevice = stateHasDataDevice
        selectionOfferID = stateSelectionOfferID
        selectionSourceID = stateSelectionSourceID
    }

    init(_ snapshot: DataTransferSeatSnapshot) {
        seatID = snapshot.seatID
        hasDataDevice = snapshot.hasDataDevice
        selectionOfferID = snapshot.selectionOfferID
        selectionSourceID = snapshot.selectionSourceID
    }

    var snapshot: DataTransferSeatSnapshot {
        DataTransferSeatSnapshot(
            seatID: seatID,
            hasDataDevice: hasDataDevice,
            selectionOfferID: selectionOfferID,
            selectionSourceID: selectionSourceID
        )
    }
}

private struct OfferState: Equatable, Sendable {
    var id: DataOfferID
    var role: DataOfferRole
    var mimeTypes: [MIMEType]

    init(
        id offerID: DataOfferID,
        role offerRole: DataOfferRole,
        mimeTypes offerMimeTypes: [MIMEType] = []
    ) {
        id = offerID
        role = offerRole
        mimeTypes = offerMimeTypes
    }

    init(_ snapshot: DataOfferSnapshot) {
        id = snapshot.id
        role = snapshot.role
        mimeTypes = snapshot.mimeTypes
    }

    var snapshot: DataOfferSnapshot {
        DataOfferSnapshot(id: id, role: role, mimeTypes: mimeTypes)
    }
}

private struct SourceState: Equatable, Sendable {
    var id: DataSourceID
    var seatID: SeatID
    var mimeTypes: [MIMEType]

    init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceTypes: [MIMEType]
    ) {
        id = sourceID
        seatID = sourceSeatID
        mimeTypes = sourceTypes
    }

    init(_ snapshot: DataSourceSnapshot) {
        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
    }

    var snapshot: DataSourceSnapshot {
        DataSourceSnapshot(id: id, seatID: seatID, mimeTypes: mimeTypes)
    }
}
