public struct ForeignToplevelID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ identifier: String) {
        rawValue = identifier
    }

    public var description: String {
        rawValue
    }
}

public struct ForeignToplevelFacts: Equatable, Sendable, Identifiable {
    public let id: ForeignToplevelID?
    public let title: String?
    public let appID: String?

    public init(id toplevelID: ForeignToplevelID?, title toplevelTitle: String?, appID app: String?) {
        id = toplevelID
        title = toplevelTitle
        appID = app
    }
}

public enum ForeignToplevelListEvent: Equatable, Sendable {
    case created(ForeignToplevelFacts)
    case updated(ForeignToplevelFacts)
    case closed(ForeignToplevelID?)
    case finished
}

public struct ForeignToplevelListSnapshot: Equatable, Sendable {
    public let toplevels: [ForeignToplevelFacts]

    public init(toplevels listedToplevels: [ForeignToplevelFacts]) {
        toplevels = listedToplevels
    }
}

extension WaylandDisplay {
    public func foreignToplevelListSnapshot() throws -> ForeignToplevelListSnapshot {
        guard try capabilities().foreignToplevelList.isAvailable else {
            throw ClientError.display(.foreignToplevelListUnavailable)
        }

        return ForeignToplevelListSnapshot(toplevels: [])
    }
}
