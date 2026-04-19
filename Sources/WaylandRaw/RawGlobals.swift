public struct RawGlobalAdvertisement: Equatable, Sendable, CustomStringConvertible {
    public let name: UInt32
    public let interfaceName: String
    public let advertisedVersion: RawVersion

    public init(
        name: UInt32,
        interfaceName: String,
        advertisedVersion: RawVersion
    ) {
        self.name = name
        self.interfaceName = interfaceName
        self.advertisedVersion = advertisedVersion
    }

    public func negotiatedVersion(
        supportedByClient clientSupportedVersion: RawVersion
    ) -> RawVersion {
        Swift.min(self.advertisedVersion, clientSupportedVersion)
    }

    public var description: String {
        "\(self.interfaceName) name=\(self.name) \(self.advertisedVersion)"
    }
}
