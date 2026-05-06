package struct DataTransferSeatState: Equatable, Sendable {
    package var seatID: SeatID
    package var hasDataDevice: Bool
    package var selection: ClipboardSelectionState

    package init(
        seatID stateSeatID: SeatID,
        hasDataDevice stateHasDataDevice: Bool = false
    ) {
        seatID = stateSeatID
        hasDataDevice = stateHasDataDevice
        selection = .none
    }

    package init(_ snapshot: DataTransferSeatSnapshot) throws {
        seatID = snapshot.seatID
        hasDataDevice = snapshot.hasDataDevice
        selection = try ClipboardSelectionState(
            offerID: snapshot.selectionOfferID,
            sourceID: snapshot.selectionSourceID
        )
    }

    package var snapshot: DataTransferSeatSnapshot {
        DataTransferSeatSnapshot(
            seatID: seatID,
            hasDataDevice: hasDataDevice,
            selectionOfferID: selection.offerID,
            selectionSourceID: selection.sourceID
        )
    }
}

package enum ClipboardSelectionState: Equatable, Sendable {
    case none
    case remoteOffer(DataOfferID)
    case ownedSource(DataSourceID)

    package init(
        offerID: DataOfferID?,
        sourceID: DataSourceID?
    ) throws {
        switch (offerID, sourceID) {
        case (nil, nil):
            self = .none
        case (.some(let offerID), nil):
            self = .remoteOffer(offerID)
        case (nil, .some(let sourceID)):
            self = .ownedSource(sourceID)
        case (.some, .some):
            throw DataTransferError.unavailable
        }
    }

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

package struct DataTransferOfferState: Equatable, Sendable {
    package var id: DataOfferID
    package var role: DataOfferRole
    package var mimeTypes: [MIMEType]

    package init(
        id offerID: DataOfferID,
        role offerRole: DataOfferRole,
        mimeTypes offerMimeTypes: [MIMEType] = []
    ) {
        id = offerID
        role = offerRole
        mimeTypes = offerMimeTypes
    }

    package init(_ snapshot: DataOfferSnapshot) {
        id = snapshot.id
        role = snapshot.role
        mimeTypes = snapshot.mimeTypes
    }

    package var snapshot: DataOfferSnapshot {
        DataOfferSnapshot(id: id, role: role, mimeTypes: mimeTypes)
    }
}

package struct DataTransferSourceState: Equatable, Sendable {
    package var id: DataSourceID
    package var seatID: SeatID
    package var mimeTypes: [MIMEType]

    package init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceTypes: [MIMEType]
    ) {
        id = sourceID
        seatID = sourceSeatID
        mimeTypes = sourceTypes
    }

    package init(_ snapshot: DataSourceSnapshot) {
        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
    }

    package var snapshot: DataSourceSnapshot {
        DataSourceSnapshot(id: id, seatID: seatID, mimeTypes: mimeTypes)
    }
}
