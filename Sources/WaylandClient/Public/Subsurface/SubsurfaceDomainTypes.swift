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

public enum SubsurfacePresentationFailureCause: Error, Equatable, Sendable,
    CustomStringConvertible
{
    case presentation(PresentationError)
    case draw(String)
    case operation(String)

    public var description: String {
        switch self {
        case .presentation(let error):
            error.description
        case .draw(let reason):
            "draw failed: \(reason)"
        case .operation(let reason):
            "operation failed: \(reason)"
        }
    }
}

public struct SubsurfacePresentationFailure: Error, Equatable, Sendable,
    CustomStringConvertible
{
    public let subsurfaceID: SubsurfaceIdentity
    public let cause: SubsurfacePresentationFailureCause

    public init(
        subsurfaceID failedSubsurfaceID: SubsurfaceIdentity,
        cause failureCause: SubsurfacePresentationFailureCause
    ) {
        subsurfaceID = failedSubsurfaceID
        cause = failureCause
    }

    public var description: String {
        "subsurface \(subsurfaceID) presentation failed: \(cause.description)"
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
}

package enum SubsurfaceParentCommitEvent: Equatable, Sendable {
    case created
    case positionChanged
    case stackingChanged
    case surfaceStateCommitted(SubsurfaceSynchronizationMode)
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

package enum SubsurfaceParentCommitPolicy {
    package static func requirement(
        parentWindowID: WindowID,
        subsurfaceID: SubsurfaceID,
        event: SubsurfaceParentCommitEvent
    ) -> SubsurfaceParentCommitRequirement? {
        switch event {
        case .created:
            requirement(
                parentWindowID: parentWindowID,
                subsurfaceID: subsurfaceID,
                reason: .created
            )
        case .positionChanged:
            requirement(
                parentWindowID: parentWindowID,
                subsurfaceID: subsurfaceID,
                reason: .positionChanged
            )
        case .stackingChanged:
            requirement(
                parentWindowID: parentWindowID,
                subsurfaceID: subsurfaceID,
                reason: .stackingChanged
            )
        case .surfaceStateCommitted(.synchronized):
            requirement(
                parentWindowID: parentWindowID,
                subsurfaceID: subsurfaceID,
                reason: .synchronizedSurfaceState
            )
        case .surfaceStateCommitted(.desynchronized):
            nil
        case .synchronizationModeChanged:
            nil
        }
    }

    private static func requirement(
        parentWindowID: WindowID,
        subsurfaceID: SubsurfaceID,
        reason: SubsurfaceParentCommitReason
    ) -> SubsurfaceParentCommitRequirement {
        SubsurfaceParentCommitRequirement(
            parentWindowID: parentWindowID,
            subsurfaceID: subsurfaceID,
            reason: reason
        )
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
