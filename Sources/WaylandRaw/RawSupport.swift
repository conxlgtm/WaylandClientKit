public struct RawProxyMetadata: Equatable, Sendable, CustomStringConvertible {
    public let interfaceName: String
    public let version: RawVersion
    public let ownership: RawOwnership
    public let objectID: RawObjectID?

    public init(
        interfaceName: String,
        version: RawVersion,
        ownership: RawOwnership,
        objectID: RawObjectID? = nil
    ) {
        self.interfaceName = interfaceName
        self.version = version
        self.ownership = ownership
        self.objectID = objectID
    }

    public var description: String {
        let objectIDDescription = self.objectID?.description ?? "id=?"
        return "\(self.interfaceName) \(objectIDDescription) \(self.version) ownership=\(self.ownership)"
    }
}
