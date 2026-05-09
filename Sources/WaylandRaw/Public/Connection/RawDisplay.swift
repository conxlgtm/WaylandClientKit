import CWaylandClientSystem

@safe
package final class RawDisplay: CustomStringConvertible {
    @safe let opaquePointer: OpaquePointer
    package let metadata: RawProxyMetadata

    @safe
    init(
        opaquePointer displayPointer: OpaquePointer,
        version: RawVersion,
        ownership: RawOwnership = .connectionLifetime,
        objectID: RawObjectID? = nil
    ) {
        unsafe opaquePointer = displayPointer
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
