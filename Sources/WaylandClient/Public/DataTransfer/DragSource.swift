import Foundation

public enum DragIcon: Equatable, Sendable {
    case none
}

public struct DragSourceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ sourceID: DataSourceID) {
        rawValue = sourceID.rawValue
    }

    public var description: String {
        "drag-source-\(rawValue)"
    }
}

public struct DragSourceConfiguration: Equatable, Sendable {
    public let payloads: [DataTransferSourcePayload]
    public let actions: DragActionSet
    package let payloadSet: DataTransferSourcePayloadSet

    public init(
        payloads sourcePayloads: [DataTransferSourcePayload],
        actions sourceActions: DragActionSet
    ) throws {
        let validatedPayloads = try DataTransferSourcePayloadSet(payloads: sourcePayloads)
        guard !sourceActions.isEmpty, sourceActions.containsOnlyKnownProtocolActions else {
            throw DataTransferError.invalidDragActionSet(rawValue: sourceActions.rawValue)
        }

        payloads = validatedPayloads.payloads
        actions = sourceActions
        payloadSet = validatedPayloads
    }

    public static func data(
        mimeType: MIMEType,
        _ data: Data,
        actions: DragActionSet
    ) throws -> DragSourceConfiguration {
        try DragSourceConfiguration(
            payloads: [DataTransferSourcePayload(mimeType: mimeType, data: data)],
            actions: actions
        )
    }

    package var mimeTypes: [MIMEType] {
        payloads.map(\.mimeType)
    }
}

public struct DragSource: Sendable, Hashable {
    package let id: DataSourceID
    public let seatID: SeatID
    public let mimeTypes: [MIMEType]
    public let actions: DragActionSet

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(snapshot: DataSourceSnapshot, display owningDisplay: WaylandDisplay) {
        precondition(
            snapshot.role.dragActions != nil,
            "DragSource requires a drag-and-drop data source snapshot"
        )

        id = snapshot.id
        seatID = snapshot.seatID
        mimeTypes = snapshot.mimeTypes
        actions = snapshot.role.dragActions ?? []
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    public var identity: DragSourceIdentity {
        DragSourceIdentity(id)
    }

    /// Cancels this source-side drag operation by destroying the underlying data source.
    public func cancel() async throws {
        try await display.cancelDragSource(id: id)
    }

    public static func == (lhs: DragSource, rhs: DragSource) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}

public struct DragSourceTargetEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let mimeType: MIMEType?

    package init(sourceID eventSourceID: DataSourceID, mimeType eventMIMEType: MIMEType?) {
        source = DragSourceIdentity(eventSourceID)
        mimeType = eventMIMEType
    }
}

public struct DragSourceActionEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let action: DragAction

    package init(sourceID eventSourceID: DataSourceID, action eventAction: DragAction) {
        source = DragSourceIdentity(eventSourceID)
        action = eventAction
    }
}

public struct DragSourceFinishedEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let finalAction: DragAction

    package init(sourceID eventSourceID: DataSourceID, finalAction eventAction: DragAction) {
        source = DragSourceIdentity(eventSourceID)
        finalAction = eventAction
    }
}
