import CWaylandClientSystem

package final class RawDisplay: CustomStringConvertible {
    let opaquePointer: OpaquePointer
    package let metadata: RawProxyMetadata

    init(
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

    package var description: String {
        metadata.description
    }
}
