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

public struct ClipboardSource: Sendable, Hashable, Identifiable {
    package let sourceID: DataSourceID
    public let id: ClipboardSourceIdentity
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<DataSourceID>

    package init(snapshot: DataSourceSnapshot, display owningDisplay: WaylandDisplay) {
        sourceID = snapshot.id
        id = snapshot.id.clipboardIdentity
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: snapshot.id, display: owningDisplay)
    }

    public var identity: ClipboardSourceIdentity {
        id
    }

    /// Requests clearing this source from the regular clipboard selection.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClear(serial: InputSerial) async throws {
        try await display.requestClearClipboard(sourceID: sourceID, seatID: seatID, serial: serial)
    }

    public static func == (lhs: ClipboardSource, rhs: ClipboardSource) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
