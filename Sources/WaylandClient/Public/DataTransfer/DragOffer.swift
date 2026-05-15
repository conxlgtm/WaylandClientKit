import Foundation

public struct DragOffer: Sendable, Hashable {
    public static let defaultReadTimeout: Duration = .seconds(5)

    package let id: DataOfferID
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]
    public let sourceActions: DragActionSet
    public let selectedAction: DragAction?

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(snapshot: DataOfferSnapshot, display owningDisplay: WaylandDisplay) {
        precondition(
            snapshot.dragAndDrop != nil,
            "DragOffer requires a drag-and-drop data offer snapshot"
        )

        id = snapshot.id
        seatID = snapshot.role.seatID
        mimeTypes = snapshot.mimeTypes
        sourceActions = snapshot.dragAndDrop?.sourceActions ?? []
        selectedAction = snapshot.dragAndDrop?.selectedAction.action
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public var identity: DragOfferIdentity {
        id.dragIdentity
    }

    public func accept(_ mimeType: MIMEType?) async throws {
        try await display.acceptDragOffer(id: id, mimeType: mimeType)
    }

    public func setActions(
        _ actions: DragActionSet,
        preferredAction: DragAction
    ) async throws {
        try await display.setDragOfferActions(
            id: id,
            actions: actions,
            preferredAction: preferredAction
        )
    }

    public func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
        try await display.receiveDragOffer(id: id, mimeType: mimeType)
    }

    public func read(
        _ mimeType: MIMEType,
        limit: ByteCount = .defaultTransferReadLimit,
        timeout: Duration = Self.defaultReadTimeout
    ) async throws -> Data {
        var descriptor = try await receive(mimeType)
        return try await descriptor.readData(limit: limit, timeout: timeout)
    }

    public func finish() async throws {
        try await display.finishDragOffer(id: id)
    }

    public func cancel() async throws {
        try await display.cancelDragOffer(id: id)
    }

    public static func == (lhs: DragOffer, rhs: DragOffer) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
