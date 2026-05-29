import Foundation

public struct DragOffer: Sendable, Hashable, Identifiable {
    public static let defaultReadTimeout: Duration = .seconds(5)

    package let offerID: DataOfferID
    public let id: DragOfferIdentity
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]
    public let sourceActions: DragActionSet
    public let selectedAction: DragAction?

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<DataOfferID>

    package init(snapshot: DataOfferSnapshot, display owningDisplay: WaylandDisplay) {
        precondition(
            snapshot.dragAndDrop != nil,
            "DragOffer requires a drag-and-drop data offer snapshot"
        )

        offerID = snapshot.id
        id = snapshot.id.dragIdentity
        seatID = snapshot.role.seatID
        mimeTypes = snapshot.mimeTypes
        sourceActions = snapshot.dragAndDrop?.sourceActions ?? []
        selectedAction = snapshot.dragAndDrop?.selectedAction.action
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: snapshot.id, display: owningDisplay)
    }

    public var identity: DragOfferIdentity {
        id
    }

    public func accept(_ mimeType: MIMEType?) async throws {
        try await display.acceptDragOffer(id: offerID, mimeType: mimeType)
    }

    public func setActions(
        _ actions: DragActionSet,
        preferredAction: DragAction
    ) async throws {
        try await display.setDragOfferActions(
            id: offerID,
            actions: actions,
            preferredAction: preferredAction
        )
    }

    public func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
        try await display.receiveDragOffer(id: offerID, mimeType: mimeType)
    }

    public func read(
        _ mimeType: MIMEType,
        limit: ByteCount = .defaultTransferReadLimit,
        timeout: Duration = Self.defaultReadTimeout
    ) async throws -> Data {
        try await readDataTransferPayload(
            mimeType,
            limit: limit,
            timeout: timeout
        )
    }

    public func finish() async throws {
        try await display.finishDragOffer(id: offerID)
    }

    public func cancel() async throws {
        try await display.cancelDragOffer(id: offerID)
    }

    public static func == (lhs: DragOffer, rhs: DragOffer) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
