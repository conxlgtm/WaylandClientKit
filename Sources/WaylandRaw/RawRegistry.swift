import CWaylandClientSystem

public final class RawRegistry: CustomStringConvertible {
    public let opaquePointer: OpaquePointer
    public let metadata: RawProxyMetadata

    public init(
        opaquePointer registryPointer: OpaquePointer,
        version: RawVersion,
        ownership: RawOwnership,
        objectID: RawObjectID? = nil
    ) {
        opaquePointer = registryPointer
        metadata = RawProxyMetadata(
            interfaceName: "wl_registry",
            version: version,
            ownership: ownership,
            objectID: objectID
        )
    }

    public var description: String {
        metadata.description
    }
}
