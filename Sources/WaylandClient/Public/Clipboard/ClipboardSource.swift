import Foundation

public struct ClipboardSourcePayload: Equatable, Sendable {
    public let mimeType: MIMEType
    public let data: Data

    public init(mimeType payloadMIMEType: MIMEType, data payloadData: Data) {
        mimeType = payloadMIMEType
        data = payloadData
    }
}

public struct ClipboardSourceConfiguration: Equatable, Sendable {
    public let payloads: [ClipboardSourcePayload]
    package let payloadSet: DataTransferSourcePayloadSet

    public init(payloads sourcePayloads: [ClipboardSourcePayload]) throws {
        let validatedPayloads = try DataTransferSourcePayloadSet(payloads: sourcePayloads)
        payloads = validatedPayloads.payloads
        payloadSet = validatedPayloads
    }

    public static func data(
        mimeType: MIMEType,
        _ data: Data
    ) throws -> ClipboardSourceConfiguration {
        try ClipboardSourceConfiguration(
            payloads: [ClipboardSourcePayload(mimeType: mimeType, data: data)]
        )
    }

    package var mimeTypes: [MIMEType] {
        payloads.map(\.mimeType)
    }
}

public struct ClipboardSource: Sendable, Hashable {
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

    public var identity: ClipboardSourceIdentity {
        ClipboardSourceIdentity(id)
    }

    /// Requests clearing this source from the regular clipboard selection.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClear(serial: InputSerial) async throws {
        try await display.requestClearClipboard(sourceID: id, seatID: seatID, serial: serial)
    }

    public static func == (lhs: ClipboardSource, rhs: ClipboardSource) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
