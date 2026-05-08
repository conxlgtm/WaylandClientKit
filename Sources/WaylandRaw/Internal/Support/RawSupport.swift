package struct RawProxyMetadata: Equatable, Sendable, CustomStringConvertible {
    package let interfaceName: String
    package let version: RawVersion
    package let ownership: RawOwnership
    package let objectID: RawObjectID?

    package init(
        interfaceName proxyInterfaceName: String,
        version proxyVersion: RawVersion,
        ownership proxyOwnership: RawOwnership,
        objectID proxyObjectID: RawObjectID? = nil
    ) {
        interfaceName = proxyInterfaceName
        version = proxyVersion
        ownership = proxyOwnership
        objectID = proxyObjectID
    }

    package var description: String {
        let objectIDDescription = objectID?.description ?? "id=?"
        return
            "\(interfaceName) \(objectIDDescription) \(version) ownership=\(ownership)"
    }
}
