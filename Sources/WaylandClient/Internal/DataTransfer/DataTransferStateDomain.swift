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

package enum DataSourceRole: Equatable, Sendable {
    case selection(seatID: SeatID)
    case dragAndDrop(seatID: SeatID, actions: DragSourceActions)

    package var seatID: SeatID {
        switch self {
        case .selection(let seatID), .dragAndDrop(let seatID, _):
            seatID
        }
    }

    package var dragActions: DragActionSet? {
        guard case .dragAndDrop(_, let actions) = self else {
            return nil
        }

        return actions.value
    }
}

package struct DragSourceActions: Equatable, Sendable {
    package let value: DragActionSet

    package init(_ actions: DragActionSet) throws {
        guard !actions.isEmpty, actions.containsOnlyKnownProtocolActions else {
            throw DataTransferError.invalidDragActionSet(rawValue: actions.rawValue)
        }

        value = actions
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

package enum DragSelectedAction: Equatable, Sendable {
    case notReceived
    case received(DragAction)

    package var action: DragAction? {
        guard case .received(let action) = self else {
            return nil
        }

        return action
    }

    package func isFinishable(finalPreferredAction: DragAction?) -> Bool {
        switch self {
        case .notReceived:
            false
        case .received(.copy):
            finalPreferredAction == nil || finalPreferredAction == .copy
        case .received(.move):
            finalPreferredAction == nil || finalPreferredAction == .move
        case .received(.ask):
            finalPreferredAction?.isFinalTransferAction == true
        case .received(.none), .received(.unknown):
            false
        }
    }
}

package enum DragAcceptState: Equatable, Sendable {
    case notSent
    case accepted(MIMEType)
    case rejected
}

package struct DragAndDropOfferMetadata: Equatable, Sendable {
    package var sourceActions: DragActionSet
    package var selectedAction: DragSelectedAction
    package var acceptState: DragAcceptState
    package var hasDropped: Bool
    package var finalPreferredAction: DragAction?
    package var enterSerial: InputSerial?

    package init(
        sourceActions offerSourceActions: DragActionSet = [],
        selectedAction offerSelectedAction: DragSelectedAction = .notReceived,
        acceptState offerAcceptState: DragAcceptState = .notSent,
        hasDropped offerHasDropped: Bool = false,
        finalPreferredAction offerFinalPreferredAction: DragAction? = nil,
        enterSerial offerEnterSerial: InputSerial? = nil
    ) {
        sourceActions = offerSourceActions
        selectedAction = offerSelectedAction
        acceptState = offerAcceptState
        hasDropped = offerHasDropped
        finalPreferredAction = offerFinalPreferredAction
        enterSerial = offerEnterSerial
    }
}

package struct DataOfferSnapshot: Equatable, Sendable {
    package let id: DataOfferID
    package let role: DataOfferRole
    package let mimeTypes: [MIMEType]
    package let dragAndDrop: DragAndDropOfferMetadata?

    package init(
        id offerID: DataOfferID,
        role offerRole: DataOfferRole,
        mimeTypes offerMIMETypes: [MIMEType],
        dragAndDrop offerDragAndDrop: DragAndDropOfferMetadata? = nil
    ) throws {
        try NonEmptyMIMETypeList.validate(
            offerMIMETypes,
            emptyError: .emptyDataOffer
        )
        id = offerID
        role = offerRole
        mimeTypes = offerMIMETypes
        switch offerRole {
        case .selection:
            dragAndDrop = nil
        case .dragAndDrop:
            dragAndDrop = offerDragAndDrop ?? DragAndDropOfferMetadata()
        }
    }
}

package struct DataSourceSnapshot: Equatable, Sendable {
    package let id: DataSourceID
    package let role: DataSourceRole
    package let mimeTypes: [MIMEType]

    package var seatID: SeatID {
        role.seatID
    }

    package init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceMIMETypes: [MIMEType]
    ) throws {
        try self.init(
            id: sourceID,
            role: .selection(seatID: sourceSeatID),
            mimeTypes: sourceMIMETypes
        )
    }

    package init(
        id sourceID: DataSourceID,
        role sourceRole: DataSourceRole,
        mimeTypes sourceMIMETypes: [MIMEType]
    ) throws {
        try NonEmptyMIMETypeList.validate(
            sourceMIMETypes,
            emptyError: .emptyDataSource
        )
        id = sourceID
        role = sourceRole
        mimeTypes = sourceMIMETypes
    }
}

package enum NonEmptyMIMETypeList {
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
    case bound(selection: DataSelectionState)

    package var hasDataDevice: Bool {
        switch self {
        case .unbound:
            false
        case .bound:
            true
        }
    }

    package var selection: DataSelectionState {
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
    package let dragAndDropOfferID: DataOfferID?

    package var hasDataDevice: Bool {
        device.hasDataDevice
    }

    package var selection: DataSelectionState {
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
        device snapshotDevice: DataTransferSeatDeviceState,
        dragAndDropOfferID snapshotDragAndDropOfferID: DataOfferID? = nil
    ) {
        seatID = snapshotSeatID
        device = snapshotDevice
        dragAndDropOfferID = snapshotDragAndDropOfferID
    }
}

package struct DataTransferDragEnterTransition: Equatable, Sendable {
    package let seatID: SeatID
    package let offerID: DataOfferID
    package let serial: InputSerial
    package let location: DragLocation
    package let target: InputEventTarget

    package init(
        seatID eventSeatID: SeatID,
        offerID eventOfferID: DataOfferID,
        serial eventSerial: InputSerial,
        location eventLocation: DragLocation,
        target eventTarget: InputEventTarget
    ) {
        seatID = eventSeatID
        offerID = eventOfferID
        serial = eventSerial
        location = eventLocation
        target = eventTarget
    }
}

package enum DataTransferAction: Equatable, Sendable {
    case seatAvailable(SeatID)
    case dataDeviceBound(SeatID)
    case seatRemoved(SeatID)
    case offerCreated(id: DataOfferID, role: DataOfferRole)
    case offerMimeType(id: DataOfferID, mimeType: MIMEType)
    case offerSourceActions(id: DataOfferID, actions: DragActionSet)
    case offerSelectedAction(id: DataOfferID, action: DragAction)
    case dragAccepted(id: DataOfferID, mimeType: MIMEType?)
    case dragActionsRequested(id: DataOfferID, preferredAction: DragAction)
    case selectionChanged(seatID: SeatID, offerID: DataOfferID?)
    case dragEntered(DataTransferDragEnterTransition)
    case dragMotion(
        seatID: SeatID,
        time: WaylandTimestampMilliseconds,
        location: DragLocation
    )
    case dragLeft(SeatID)
    case dragDropped(SeatID)
    case dragFinished(DataOfferID)
    case dragCancelled(DataOfferID)
    case sourceCreated(id: DataSourceID, seatID: SeatID, mimeTypes: [MIMEType])
    case dragSourceCreated(
        id: DataSourceID,
        seatID: SeatID,
        mimeTypes: [MIMEType],
        actions: DragActionSet
    )
    case dragSourceTargetChanged(id: DataSourceID, mimeType: MIMEType?)
    case dragSourceActionChanged(id: DataSourceID, action: DragAction)
    case dragSourceDropPerformed(DataSourceID)
    case dragSourceFinished(DataSourceID)
    case dragSourceInvalidFinished(DataSourceID)
    case selectionSourceChanged(seatID: SeatID, sourceID: DataSourceID?)
    case sourceCancelled(DataSourceID)
}

package enum DataTransferEffect: Equatable, Sendable {
    case bindDataDevice(SeatID)
    case releaseDataDevice(SeatID)
    case destroyOffer(DataOfferID)
    case destroySource(DataSourceID)
    case cancelSource(DataSourceID)
    case publishSelectionChanged(seatID: SeatID, offerID: DataOfferID?)
    case publishDragEntered(DataTransferDragEnterTransition)
    case publishDragMotion(
        seatID: SeatID, offerID: DataOfferID, time: WaylandTimestampMilliseconds,
        location: DragLocation)
    case publishDragLeft(seatID: SeatID, offerID: DataOfferID)
    case publishDragDropped(seatID: SeatID, offerID: DataOfferID)
    case publishDragOfferChanged(seatID: SeatID, offerID: DataOfferID)
    case publishSourceCancelled(DataSourceID)
    case publishDragSourceCancelled(DataSourceID)
    case publishDragSourceTargetChanged(id: DataSourceID, mimeType: MIMEType?)
    case publishDragSourceActionChanged(id: DataSourceID, action: DragAction)
    case publishDragSourceDropPerformed(DataSourceID)
    case publishDragSourceFinished(id: DataSourceID, finalAction: DragSourceFinalAction)
}

package struct DataTransferTransitionPlan: Equatable, Sendable {
    package let state: DataTransferState
    package let effects: [DataTransferEffect]
}
