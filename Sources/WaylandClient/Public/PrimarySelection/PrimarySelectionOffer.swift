import Foundation

public struct PrimarySelectionOffer: Sendable, Hashable, Identifiable {
    public static let defaultReadTimeout: Duration = .seconds(5)

    package let offerID: DataOfferID
    public let id: PrimarySelectionOfferIdentity
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<DataOfferID>

    package init(snapshot: DataOfferSnapshot, display owningDisplay: WaylandDisplay) {
        offerID = snapshot.id
        id = snapshot.id.primarySelectionIdentity
        seatID = snapshot.role.seatID
        mimeTypes = snapshot.mimeTypes
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: snapshot.id, display: owningDisplay)
    }

    public var identity: PrimarySelectionOfferIdentity {
        id
    }

    public func receive(_ mimeType: MIMEType) async throws -> OwnedFileDescriptor {
        try await display.receivePrimarySelectionOffer(id: offerID, mimeType: mimeType)
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

    public static func == (lhs: PrimarySelectionOffer, rhs: PrimarySelectionOffer) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
