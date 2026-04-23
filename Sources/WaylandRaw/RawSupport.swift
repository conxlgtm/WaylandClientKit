public struct RawProxyMetadata: Equatable, Sendable, CustomStringConvertible {
    public let interfaceName: String
    public let version: RawVersion
    public let ownership: RawOwnership
    public let objectID: RawObjectID?

    public init(
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

    public var description: String {
        let objectIDDescription = objectID?.description ?? "id=?"
        return
            "\(interfaceName) \(objectIDDescription) \(version) ownership=\(ownership)"
    }
}
