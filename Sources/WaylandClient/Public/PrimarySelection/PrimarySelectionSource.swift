import Foundation

public struct PrimarySelectionSourceConfiguration: Equatable, Sendable {
    public let payloads: [DataTransferSourcePayload]
    package let payloadSet: DataTransferSourcePayloadSet

    public init(payloads sourcePayloads: [DataTransferSourcePayload]) throws {
        let validatedPayloads = try DataTransferSourcePayloadSet(payloads: sourcePayloads)
        payloads = validatedPayloads.payloads
        payloadSet = validatedPayloads
    }

    public static func data(
        mimeType: MIMEType,
        _ data: Data
    ) throws -> PrimarySelectionSourceConfiguration {
        try PrimarySelectionSourceConfiguration(
            payloads: [DataTransferSourcePayload(mimeType: mimeType, data: data)]
        )
    }

    package var mimeTypes: [MIMEType] {
        payloads.map(\.mimeType)
    }
}

public struct PrimarySelectionSource: Sendable, Hashable {
    package let id: DataSourceID
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(snapshot: DataSourceSnapshot, display owningDisplay: WaylandDisplay) {
        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public var identity: PrimarySelectionSourceIdentity {
        PrimarySelectionSourceIdentity(id)
    }

    /// Requests clearing this source from the primary selection.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClear(serial: InputSerial) async throws {
        try await display.requestClearPrimarySelection(sourceID: id, seatID: seatID, serial: serial)
    }

    public static func == (lhs: PrimarySelectionSource, rhs: PrimarySelectionSource) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
