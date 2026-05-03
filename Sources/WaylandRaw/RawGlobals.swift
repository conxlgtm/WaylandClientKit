package struct RawGlobalAdvertisement: Equatable, Sendable, CustomStringConvertible {
    package let name: UInt32
    package let interfaceName: String
    package let advertisedVersion: RawVersion

    package init(
        name globalName: UInt32,
        interfaceName globalInterfaceName: String,
        advertisedVersion globalAdvertisedVersion: RawVersion
    ) {
        name = globalName
        interfaceName = globalInterfaceName
        advertisedVersion = globalAdvertisedVersion
    }

    package func negotiatedVersion(
        supportedByClient clientSupportedVersion: RawVersion
    ) -> RawVersion {
        Swift.min(advertisedVersion, clientSupportedVersion)
    }

    package var description: String {
        "\(interfaceName) name=\(name) \(advertisedVersion)"
    }
}
