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

    package init(
        id offerID: DataOfferID,
        role offerRole: DataOfferRole,
        mimeTypes offerMIMETypes: [MIMEType]
    ) throws {
        try NonEmptyMIMETypeList.validate(
            offerMIMETypes,
            emptyError: .emptyDataOffer
        )
        id = offerID
        role = offerRole
        mimeTypes = offerMIMETypes
    }
}

package struct DataSourceSnapshot: Equatable, Sendable {
    package let id: DataSourceID
    package let seatID: SeatID
    package let mimeTypes: [MIMEType]

    package init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceMIMETypes: [MIMEType]
    ) throws {
        try NonEmptyMIMETypeList.validate(
            sourceMIMETypes,
            emptyError: .emptyDataSource
        )
        id = sourceID
        seatID = sourceSeatID
        mimeTypes = sourceMIMETypes
    }
}

package struct NonEmptyMIMETypeList: Equatable, Sendable {
    package let values: [MIMEType]

    package init(
        _ mimeTypes: [MIMEType],
        emptyError: DataTransferError
    ) throws {
        try Self.validate(mimeTypes, emptyError: emptyError)
        values = mimeTypes
    }

    package static func validate(
        _ mimeTypes: [MIMEType],
        emptyError: DataTransferError
    ) throws {
        guard !mimeTypes.isEmpty else {
            throw emptyError
        }

        var seenMIMETypes: Set<MIMEType> = []
        for mimeType in mimeTypes {
            guard seenMIMETypes.insert(mimeType).inserted else {
                throw DataTransferError.duplicateMIMEType(mimeType)
            }
        }
    }
}

package enum DataTransferSeatDeviceState: Equatable, Sendable {
    case unbound
    case bound(selection: ClipboardSelectionState)

    package var hasDataDevice: Bool {
        switch self {
        case .unbound:
            false
        case .bound:
            true
        }
    }

    package var selection: ClipboardSelectionState {
        switch self {
        case .unbound:
            .none
        case .bound(let selection):
            selection
        }
    }
}

package struct DataTransferSeatSnapshot: Equatable, Sendable {
    package let seatID: SeatID
    package let device: DataTransferSeatDeviceState

    package var hasDataDevice: Bool {
        device.hasDataDevice
    }

    package var selection: ClipboardSelectionState {
        device.selection
    }

    package var selectionOfferID: DataOfferID? {
        selection.offerID
    }

    package var selectionSourceID: DataSourceID? {
        selection.sourceID
    }

    package init(
        seatID snapshotSeatID: SeatID,
        device snapshotDevice: DataTransferSeatDeviceState
    ) {
        seatID = snapshotSeatID
        device = snapshotDevice
    }
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
