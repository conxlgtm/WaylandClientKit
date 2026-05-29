public struct SubsurfaceIdentity: Hashable, Sendable, CustomStringConvertible {
    package let rawValue: UInt64

    package init(_ subsurfaceID: SubsurfaceID) {
        rawValue = subsurfaceID.rawValue
    }

    public var description: String {
        "subsurface-\(rawValue)"
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
