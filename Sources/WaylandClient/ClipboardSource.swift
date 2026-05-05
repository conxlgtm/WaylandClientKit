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

    public init(payloads sourcePayloads: [ClipboardSourcePayload]) throws {
        guard !sourcePayloads.isEmpty else {
            throw DataTransferError.emptyDataSource
        }

        var seenMIMETypes: Set<MIMEType> = []
        for payload in sourcePayloads {
            guard seenMIMETypes.insert(payload.mimeType).inserted else {
                throw DataTransferError.duplicateMIMEType(payload.mimeType)
            }
        }

        payloads = sourcePayloads
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

    package var dataProvider: DataTransferSourceProvider {
        var payloadsByMIMEType: [MIMEType: Data] = [:]
        for payload in payloads {
            payloadsByMIMEType[payload.mimeType] = payload.data
        }

        return DataTransferSourceProvider(data: payloadsByMIMEType)
    }
}

public struct ClipboardSource: Sendable, Hashable {
    package let id: DataSourceID
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]

    private let displayIdentity: ObjectIdentifier

    package init(snapshot: DataSourceSnapshot, display owningDisplay: WaylandDisplay) {
        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public var identity: ClipboardSourceIdentity {
        ClipboardSourceIdentity(id)
    }

    public static func == (lhs: ClipboardSource, rhs: ClipboardSource) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
