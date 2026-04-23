public struct RawGlobalAdvertisement: Equatable, Sendable, CustomStringConvertible {
    public let name: UInt32
    public let interfaceName: String
    public let advertisedVersion: RawVersion

    public init(
        name globalName: UInt32,
        interfaceName globalInterfaceName: String,
        advertisedVersion globalAdvertisedVersion: RawVersion
    ) {
        name = globalName
        interfaceName = globalInterfaceName
        advertisedVersion = globalAdvertisedVersion
    }

    public func negotiatedVersion(
        supportedByClient clientSupportedVersion: RawVersion
    ) -> RawVersion {
        Swift.min(advertisedVersion, clientSupportedVersion)
    }

    public var description: String {
        "\(interfaceName) name=\(name) \(advertisedVersion)"
    }
}
