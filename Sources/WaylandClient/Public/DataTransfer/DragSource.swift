import Foundation

public enum DragIcon: Equatable, Sendable {
    case none
    case xrgb8888(DragIconImage)
}

public struct DragIconImage: Equatable, Sendable {
    public let size: PositivePixelSize
    public let pixels: [UInt32]

    public init(size imageSize: PositivePixelSize, pixels xrgb8888Pixels: [UInt32]) throws {
        let width = Int(imageSize.width.rawValue)
        let height = Int(imageSize.height.rawValue)
        try Self.validatePixelCount(
            width: width,
            height: height,
            actual: xrgb8888Pixels.count
        )

        size = imageSize
        pixels = xrgb8888Pixels
    }

    public static func solid(
        size imageSize: PositivePixelSize,
        color xrgb8888Color: UInt32
    ) throws -> DragIconImage {
        let width = Int(imageSize.width.rawValue)
        let height = Int(imageSize.height.rawValue)
        let expectedCount = try expectedPixelCount(
            width: width,
            height: height,
            actualForError: 0
        )
        return try DragIconImage(
            size: imageSize,
            pixels: Array(repeating: xrgb8888Color, count: expectedCount)
        )
    }

    @discardableResult
    package static func validatePixelCount(
        width: Int,
        height: Int,
        actual: Int
    ) throws(DataTransferError) -> Int {
        let expectedCount = try expectedPixelCount(
            width: width,
            height: height,
            actualForError: actual
        )

        guard actual == expectedCount else {
            throw DataTransferError.invalidDragIconPixelCount(
                expected: expectedCount,
                actual: actual
            )
        }

        return expectedCount
    }

    private static func expectedPixelCount(
        width: Int,
        height: Int,
        actualForError actual: Int
    ) throws(DataTransferError) -> Int {
        let (expectedCount, overflowed) = width.multipliedReportingOverflow(
            by: height
        )
        guard !overflowed else {
            throw DataTransferError.invalidDragIconPixelCount(
                expected: Int.max,
                actual: actual
            )
        }

        return expectedCount
    }
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
    private let ownership: DisplayOwnedIdentity<DataSourceID>

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
        ownership = DisplayOwnedIdentity(id: snapshot.id, display: owningDisplay)
    }

    public var identity: DragSourceIdentity {
        id.dragIdentity
    }

    /// Cancels this source-side drag operation by destroying the underlying data source.
    public func cancel() async throws {
        try await display.cancelDragSource(id: id)
    }

    public static func == (lhs: DragSource, rhs: DragSource) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}

public struct DragSourceTargetEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let mimeType: MIMEType?

    package init(sourceID eventSourceID: DataSourceID, mimeType eventMIMEType: MIMEType?) {
        source = eventSourceID.dragIdentity
        mimeType = eventMIMEType
    }
}

public struct DragSourceActionEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let action: DragAction

    package init(sourceID eventSourceID: DataSourceID, action eventAction: DragAction) {
        source = eventSourceID.dragIdentity
        action = eventAction
    }
}

public enum DragSourceFinalAction: Equatable, Sendable, CustomStringConvertible {
    case copy
    case move
    case unknown(rawValue: UInt32)

    package init(_ action: DragAction) throws {
        switch action {
        case .copy:
            self = .copy
        case .move:
            self = .move
        case .unknown(let rawValue):
            self = .unknown(rawValue: rawValue)
        case .none, .ask:
            throw DataTransferError.invalidSourceEvent(.dndFinished)
        }
    }

    public var description: String {
        switch self {
        case .copy:
            "copy"
        case .move:
            "move"
        case .unknown(let rawValue):
            "unknown(\(rawValue))"
        }
    }
}

public struct DragSourceFinishedEvent: Equatable, Sendable {
    public let source: DragSourceIdentity
    public let finalAction: DragSourceFinalAction

    package init(
        sourceID eventSourceID: DataSourceID,
        finalAction eventAction: DragSourceFinalAction
    ) {
        source = eventSourceID.dragIdentity
        finalAction = eventAction
    }
}
