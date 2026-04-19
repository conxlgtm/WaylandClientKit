import CWaylandClientSystem

public final class RawDisplay: CustomStringConvertible {
    public let opaquePointer: OpaquePointer
    public let metadata: RawProxyMetadata

    public init(
        opaquePointer: OpaquePointer,
        version: RawVersion,
        ownership: RawOwnership = .connectionLifetime,
        objectID: RawObjectID? = nil
    ) {
        self.opaquePointer = opaquePointer
        self.metadata = RawProxyMetadata(
            interfaceName: "wl_display",
            version: version,
            ownership: ownership,
            objectID: objectID
        )
    }

    public var description: String {
        self.metadata.description
    }
}
