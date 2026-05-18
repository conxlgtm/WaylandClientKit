import Foundation

public struct ClipboardSourceConfiguration: Equatable, Sendable {
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
    ) throws -> ClipboardSourceConfiguration {
        try ClipboardSourceConfiguration(
            payloads: [DataTransferSourcePayload(mimeType: mimeType, data: data)]
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
    private let ownership: DisplayOwnedIdentity<DataSourceID>

    package init(snapshot: DataSourceSnapshot, display owningDisplay: WaylandDisplay) {
        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: snapshot.id, display: owningDisplay)
    }

    public var identity: ClipboardSourceIdentity {
        id.clipboardIdentity
    }

    /// Requests clearing this source from the regular clipboard selection.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClear(serial: InputSerial) async throws {
        try await display.requestClearClipboard(sourceID: id, seatID: seatID, serial: serial)
    }

    public static func == (lhs: ClipboardSource, rhs: ClipboardSource) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
