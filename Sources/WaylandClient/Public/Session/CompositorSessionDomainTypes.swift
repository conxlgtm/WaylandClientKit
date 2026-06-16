import WaylandRaw

public struct CompositorSessionID:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    public let value: String

    public init(_ sessionID: String) throws {
        guard !sessionID.isEmpty, !sessionID.contains("\0") else {
            throw ClientError.display(.invalidCompositorSessionID)
        }

        value = sessionID
    }

    package init(unchecked sessionID: String) {
        value = sessionID
    }

    public var description: String {
        value
    }
}

public enum CompositorSessionReason: Equatable, Sendable {
    case launch
    case recover
    case sessionRestore

    package var rawReason: RawCompositorSessionReason {
        switch self {
        case .launch:
            .launch
        case .recover:
            .recover
        case .sessionRestore:
            .sessionRestore
        }
    }
}

public enum CompositorSessionEvent: Equatable, Sendable {
    case created(CompositorSessionID)
    case restored
    case replaced
}

public struct CompositorSessionEventSnapshot: Equatable, Sendable {
    public let events: [CompositorSessionEvent]

    public init(events sessionEvents: [CompositorSessionEvent]) {
        events = sessionEvents
    }
}
