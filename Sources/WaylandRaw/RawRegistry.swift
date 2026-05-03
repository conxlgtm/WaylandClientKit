import CWaylandClientSystem

package final class RawRegistry: CustomStringConvertible {
    let opaquePointer: OpaquePointer
    package let metadata: RawProxyMetadata

    init(
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

    package var description: String {
        metadata.description
    }
}
