public struct SubsurfaceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ subsurfaceID: SubsurfaceID) {
        rawValue = subsurfaceID.rawValue
    }

    public var description: String {
        "subsurface-\(rawValue)"
    }
}

public enum SubsurfaceStackingError: Error, Equatable, Sendable, CustomStringConvertible {
    case selfReference(SubsurfaceIdentity)
    case differentParent(subsurface: SubsurfaceIdentity, sibling: SubsurfaceIdentity)

    public var description: String {
        switch self {
        case .selfReference(let subsurfaceID):
            "subsurface cannot be stacked relative to itself: \(subsurfaceID)"
        case .differentParent(let subsurfaceID, let siblingID):
            "subsurface \(subsurfaceID) cannot be stacked relative to "
                + "\(siblingID) because they have different parent surfaces"
        }
    }
}

public struct SubsurfacePresentationFailure: Error, Equatable, Sendable,
    CustomStringConvertible
{
    public let subsurfaceID: SubsurfaceIdentity
    public let reason: String

    public init(subsurfaceID failedSubsurfaceID: SubsurfaceIdentity, reason failureReason: String) {
        subsurfaceID = failedSubsurfaceID
        reason = failureReason
    }

    public var description: String {
        "subsurface \(subsurfaceID) presentation failed: \(reason)"
    }
}

package struct SubsurfaceID:
    UInt64WaylandEntityID,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue subsurfaceRawValue: UInt64) {
        rawValue = subsurfaceRawValue
    }

    package var description: String {
        "subsurface-\(rawValue)"
    }
}

public enum SubsurfaceSynchronizationMode: Equatable, Sendable {
    case synchronized
    case desynchronized
}

package enum SubsurfaceParentCommitReason: Equatable, Sendable {
    case created
    case positionChanged
    case stackingChanged
    case synchronizedSurfaceState
    case synchronizationModeChanged
}

package struct SubsurfaceParentCommitRequirement: Equatable, Sendable {
    package let parentWindowID: WindowID
    package let subsurfaceID: SubsurfaceID
    package let reason: SubsurfaceParentCommitReason

    package init(
        parentWindowID subsurfaceParentWindowID: WindowID,
        subsurfaceID managedSubsurfaceID: SubsurfaceID,
        reason commitReason: SubsurfaceParentCommitReason
    ) {
        parentWindowID = subsurfaceParentWindowID
        subsurfaceID = managedSubsurfaceID
        reason = commitReason
    }
}

public struct SubsurfaceConfiguration: Equatable, Sendable {
    public static let defaultBufferCount = PositiveInt(unchecked: 3)

    public let position: LogicalOffset
    public let size: PositiveLogicalSize
    public let bufferCount: PositiveInt
    public let synchronizationMode: SubsurfaceSynchronizationMode

    public init(
        position subsurfacePosition: LogicalOffset = LogicalOffset(x: 0, y: 0),
        size subsurfaceSize: PositiveLogicalSize = .default,
        bufferCount subsurfaceBufferCount: PositiveInt = Self.defaultBufferCount,
        synchronizationMode subsurfaceSynchronizationMode:
            SubsurfaceSynchronizationMode = .synchronized
    ) {
        position = subsurfacePosition
        size = subsurfaceSize
        bufferCount = subsurfaceBufferCount
        synchronizationMode = subsurfaceSynchronizationMode
    }
}
