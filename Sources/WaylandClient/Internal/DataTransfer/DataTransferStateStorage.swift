package struct DataTransferSeatState: Equatable, Sendable {
    package var seatID: SeatID
    package var device: DataTransferSeatDeviceState

    package init(
        seatID stateSeatID: SeatID,
        hasDataDevice stateHasDataDevice: Bool = false
    ) {
        seatID = stateSeatID
        device = stateHasDataDevice ? .bound(selection: .none) : .unbound
    }

    package init(_ snapshot: DataTransferSeatSnapshot) throws {
        seatID = snapshot.seatID
        device = snapshot.device
    }

    package var snapshot: DataTransferSeatSnapshot {
        DataTransferSeatSnapshot(
            seatID: seatID,
            device: device
        )
    }

    package var hasDataDevice: Bool {
        device.hasDataDevice
    }

    package var selection: ClipboardSelectionState {
        device.selection
    }

    package mutating func bindDataDevice() {
        guard case .unbound = device else {
            return
        }

        device = .bound(selection: .none)
    }

    package mutating func unbindDataDevice() {
        device = .unbound
    }

    package mutating func setSelection(_ selection: ClipboardSelectionState) throws {
        guard device.hasDataDevice else {
            throw DataTransferError.missingDataDevice(seatID)
        }

        device = .bound(selection: selection)
    }
}

package enum ClipboardSelectionState: Equatable, Sendable {
    case none
    case remoteOffer(DataOfferID)
    case ownedSource(DataSourceID)

    package static func fromRemoteOffer(_ offerID: DataOfferID?) -> ClipboardSelectionState {
        if let offerID {
            .remoteOffer(offerID)
        } else {
            .none
        }
    }

    package static func fromOwnedSource(_ sourceID: DataSourceID?) -> ClipboardSelectionState {
        if let sourceID {
            .ownedSource(sourceID)
        } else {
            .none
        }
    }

    package var offerID: DataOfferID? {
        guard case .remoteOffer(let offerID) = self else {
            return nil
        }

        return offerID
    }

    package var sourceID: DataSourceID? {
        guard case .ownedSource(let sourceID) = self else {
            return nil
        }

        return sourceID
    }

    package var hasAnySelection: Bool {
        self != .none
    }
}

package enum DataTransferOfferState: Equatable, Sendable {
    case pending(id: DataOfferID, role: DataOfferRole, mimeTypes: [MIMEType])
    case selectable(DataOfferSnapshot)

    package init(id offerID: DataOfferID, role offerRole: DataOfferRole) {
        self = .pending(id: offerID, role: offerRole, mimeTypes: [])
    }

    package init(_ snapshot: DataOfferSnapshot) {
        self = .selectable(snapshot)
    }

    package var id: DataOfferID {
        switch self {
        case .pending(let id, _, _):
            id
        case .selectable(let snapshot):
            snapshot.id
        }
    }

    package var role: DataOfferRole {
        switch self {
        case .pending(_, let role, _):
            role
        case .selectable(let snapshot):
            snapshot.role
        }
    }

    package var mimeTypes: [MIMEType] {
        switch self {
        case .pending(_, _, let mimeTypes):
            mimeTypes
        case .selectable(let snapshot):
            snapshot.mimeTypes
        }
    }

    package var snapshot: DataOfferSnapshot? {
        guard case .selectable(let snapshot) = self else {
            return nil
        }

        return snapshot
    }

    package mutating func appendMIMETypeIfNew(_ mimeType: MIMEType) throws -> Bool {
        guard !mimeTypes.contains(mimeType) else {
            return false
        }

        let nextMIMETypes = mimeTypes + [mimeType]
        self = .selectable(
            try DataOfferSnapshot(id: id, role: role, mimeTypes: nextMIMETypes)
        )
        return true
    }
}

package struct DataTransferSourceState: Equatable, Sendable {
    private var storage: DataSourceSnapshot

    package init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceTypes: [MIMEType]
    ) throws {
        storage = try DataSourceSnapshot(
            id: sourceID,
            seatID: sourceSeatID,
            mimeTypes: sourceTypes
        )
    }

    package init(_ snapshot: DataSourceSnapshot) {
        storage = snapshot
    }

    package var id: DataSourceID {
        storage.id
    }

    package var seatID: SeatID {
        storage.seatID
    }

    package var mimeTypes: [MIMEType] {
        storage.mimeTypes
    }

    package var snapshot: DataSourceSnapshot {
        storage
    }
}
