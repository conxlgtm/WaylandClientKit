import CWaylandClientSystem

public final class RawDisplay: CustomStringConvertible {
    public let opaquePointer: OpaquePointer
    public let metadata: RawProxyMetadata

    public init(
        opaquePointer displayPointer: OpaquePointer,
        version: RawVersion,
        ownership: RawOwnership = .connectionLifetime,
        objectID: RawObjectID? = nil
    ) {
        opaquePointer = displayPointer
        metadata = RawProxyMetadata(
            interfaceName: "wl_display",
            version: version,
            ownership: ownership,
            objectID: objectID
        )
    }

    public var description: String {
        metadata.description
    }
}
