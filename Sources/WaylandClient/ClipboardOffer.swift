public struct ClipboardOffer: Sendable, Hashable {
    package let id: DataOfferID
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(snapshot: DataOfferSnapshot, display owningDisplay: WaylandDisplay) {
        id = snapshot.id
        seatID = snapshot.role.seatID
        mimeTypes = snapshot.mimeTypes
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public var identity: ClipboardOfferIdentity {
        ClipboardOfferIdentity(id)
    }

    public func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
        try await display.receiveClipboardOffer(id: id, mimeType: mimeType)
    }

    public static func == (lhs: ClipboardOffer, rhs: ClipboardOffer) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
