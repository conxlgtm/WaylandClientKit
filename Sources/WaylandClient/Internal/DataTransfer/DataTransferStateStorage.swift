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
    case pending(
        id: DataOfferID,
        role: DataOfferRole,
        mimeTypes: [MIMEType],
        dragAndDrop: DragAndDropOfferMetadata?
    )
    case selectable(DataOfferSnapshot)

    package init(id offerID: DataOfferID, role offerRole: DataOfferRole) {
        let dragAndDrop: DragAndDropOfferMetadata?
        switch offerRole {
        case .selection:
            dragAndDrop = nil
        case .dragAndDrop:
            dragAndDrop = DragAndDropOfferMetadata()
        }
        self = .pending(
            id: offerID,
            role: offerRole,
            mimeTypes: [],
            dragAndDrop: dragAndDrop
        )
    }

    package init(_ snapshot: DataOfferSnapshot) {
        self = .selectable(snapshot)
    }

    package var id: DataOfferID {
        switch self {
        case .pending(let id, _, _, _):
            id
        case .selectable(let snapshot):
            snapshot.id
        }
    }

    package var role: DataOfferRole {
        switch self {
        case .pending(_, let role, _, _):
            role
        case .selectable(let snapshot):
            snapshot.role
        }
    }

    package var mimeTypes: [MIMEType] {
        switch self {
        case .pending(_, _, let mimeTypes, _):
            mimeTypes
        case .selectable(let snapshot):
            snapshot.mimeTypes
        }
    }

    package var dragAndDrop: DragAndDropOfferMetadata? {
        switch self {
        case .pending(_, _, _, let dragAndDrop):
            dragAndDrop
        case .selectable(let snapshot):
            snapshot.dragAndDrop
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
            try DataOfferSnapshot(
                id: id,
                role: role,
                mimeTypes: nextMIMETypes,
                dragAndDrop: dragAndDrop
            )
        )
        return true
    }

    package mutating func setDragSourceActions(_ actions: DragActionSet) throws -> Bool {
        var metadata = try requireDragAndDropMetadata()
        guard metadata.sourceActions != actions else {
            return false
        }

        metadata.sourceActions = actions
        try replaceDragAndDropMetadata(metadata)
        return true
    }

    package mutating func setDragSelectedAction(_ action: DragAction) throws -> Bool {
        var metadata = try requireDragAndDropMetadata()
        let nextSelection = DragSelectedAction.received(action)
        guard metadata.selectedAction != nextSelection else {
            return false
        }

        metadata.selectedAction = nextSelection
        try replaceDragAndDropMetadata(metadata)
        return true
    }

    package mutating func setDragAcceptState(_ acceptState: DragAcceptState) throws {
        var metadata = try requireDragAndDropMetadata()
        metadata.acceptState = acceptState
        try replaceDragAndDropMetadata(metadata)
    }

    package mutating func recordFinalPreferredAction(_ action: DragAction) throws {
        var metadata = try requireDragAndDropMetadata()
        guard metadata.hasDropped || metadata.selectedAction == .received(.ask) else {
            return
        }

        metadata.finalPreferredAction = action
        try replaceDragAndDropMetadata(metadata)
    }

    package mutating func markDragDropped() throws {
        var metadata = try requireDragAndDropMetadata()
        metadata.hasDropped = true
        try replaceDragAndDropMetadata(metadata)
    }

    package mutating func setDragEnterSerial(_ serial: InputSerial) throws {
        var metadata = try requireDragAndDropMetadata()
        metadata.enterSerial = serial
        try replaceDragAndDropMetadata(metadata)
    }

    private func requireDragAndDropMetadata() throws -> DragAndDropOfferMetadata {
        guard let dragAndDrop else {
            throw DataTransferError.unknownOffer
        }

        return dragAndDrop
    }

    private mutating func replaceDragAndDropMetadata(
        _ metadata: DragAndDropOfferMetadata
    ) throws {
        switch self {
        case .pending(let id, let role, let mimeTypes, _):
            self = .pending(
                id: id,
                role: role,
                mimeTypes: mimeTypes,
                dragAndDrop: metadata
            )
        case .selectable(let snapshot):
            self = .selectable(
                try DataOfferSnapshot(
                    id: snapshot.id,
                    role: snapshot.role,
                    mimeTypes: snapshot.mimeTypes,
                    dragAndDrop: metadata
                )
            )
        }
    }
}

package struct DataTransferSourceState: Equatable, Sendable {
    private var storage: DataSourceSnapshot
    private var selectedDragAction: DragAction?
    private var hasDragDropped: Bool

    package init(
        id sourceID: DataSourceID,
        seatID sourceSeatID: SeatID,
        mimeTypes sourceTypes: [MIMEType]
    ) throws {
        try self.init(
            id: sourceID,
            role: .selection(seatID: sourceSeatID),
            mimeTypes: sourceTypes
        )
    }

    package init(
        id sourceID: DataSourceID,
        role sourceRole: DataSourceRole,
        mimeTypes sourceTypes: [MIMEType]
    ) throws {
        storage = try DataSourceSnapshot(
            id: sourceID,
            role: sourceRole,
            mimeTypes: sourceTypes
        )
        selectedDragAction = nil
        hasDragDropped = false
    }

    package init(_ snapshot: DataSourceSnapshot) {
        storage = snapshot
        selectedDragAction = nil
        hasDragDropped = false
    }

    package var id: DataSourceID {
        storage.id
    }

    package var seatID: SeatID {
        storage.seatID
    }

    package var role: DataSourceRole {
        storage.role
    }

    package var mimeTypes: [MIMEType] {
        storage.mimeTypes
    }

    package var snapshot: DataSourceSnapshot {
        storage
    }

    package mutating func setSelectedDragAction(_ action: DragAction) throws {
        let availableActions = try requireDragSourceActions()
        try validateSelectedDragAction(action, availableActions: availableActions)
        guard canApplySelectedDragActionAfterDrop(action) else {
            throw DataTransferError.invalidSourceEvent(.action)
        }

        selectedDragAction = action
    }

    package mutating func markDragDropped() throws -> Bool {
        _ = try requireDragSourceActions()
        guard !hasDragDropped else {
            return false
        }

        hasDragDropped = true
        return true
    }

    package func finishedDragAction() throws -> DragAction {
        _ = try requireDragSourceActions()
        guard hasDragDropped, let selectedDragAction else {
            throw DataTransferError.invalidSourceEvent(.dndFinished)
        }

        return selectedDragAction
    }

    private func requireDragSourceActions() throws -> DragActionSet {
        guard let actions = storage.role.dragActions else {
            throw DataTransferError.unknownDragSourceIdentity(DragSourceIdentity(id))
        }

        return actions
    }

    private func validateSelectedDragAction(
        _ action: DragAction,
        availableActions: DragActionSet
    ) throws {
        guard action != .none, action.isKnownProtocolAction else {
            return
        }
        guard availableActions.contains(action.actionSetMember) else {
            throw DataTransferError.unsupportedDragAction(
                action: action,
                available: availableActions
            )
        }
    }

    private func canApplySelectedDragActionAfterDrop(_ action: DragAction) -> Bool {
        guard hasDragDropped, let selectedDragAction else {
            return true
        }
        guard selectedDragAction != .ask else {
            return true
        }

        return action == selectedDragAction
    }
}
