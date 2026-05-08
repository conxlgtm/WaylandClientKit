package struct RawGlobalAdvertisement: Equatable, Sendable, CustomStringConvertible {
    package let name: UInt32
    package let interfaceName: String
    package let advertisedVersion: RawVersion

    package init?(
        name globalName: UInt32,
        interfaceName globalInterfaceName: String,
        advertisedVersion globalAdvertisedVersion: RawVersion
    ) {
        guard
            Self.validationFailure(
                interfaceName: globalInterfaceName,
                advertisedVersion: globalAdvertisedVersion
            ) == nil
        else {
            return nil
        }

        name = globalName
        interfaceName = globalInterfaceName
        advertisedVersion = globalAdvertisedVersion
    }

    package static func validationFailure(
        interfaceName globalInterfaceName: String,
        advertisedVersion globalAdvertisedVersion: RawVersion
    ) -> RawGlobalAdvertisementValidationFailure? {
        guard !globalInterfaceName.isEmpty else {
            return .emptyInterfaceName
        }
        guard !globalInterfaceName.contains("\0") else {
            return .interfaceNameContainsNUL
        }
        guard globalAdvertisedVersion.value > 0 else {
            return .zeroAdvertisedVersion
        }

        return nil
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

package enum RawGlobalAdvertisementValidationFailure:
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case emptyInterfaceName
    case interfaceNameContainsNUL
    case zeroAdvertisedVersion

    package var description: String {
        switch self {
        case .emptyInterfaceName:
            "empty interface name"
        case .interfaceNameContainsNUL:
            "interface name contains NUL"
        case .zeroAdvertisedVersion:
            "zero advertised version"
        }
    }
}

package struct RawGlobalAdvertisementRejection:
    Equatable,
    Sendable,
    CustomStringConvertible
{
    package let name: UInt32
    package let interfaceName: String
    package let advertisedVersion: RawVersion
    package let failure: RawGlobalAdvertisementValidationFailure

    package init(
        name globalName: UInt32,
        interfaceName globalInterfaceName: String,
        advertisedVersion globalAdvertisedVersion: RawVersion,
        failure validationFailure: RawGlobalAdvertisementValidationFailure
    ) {
        name = globalName
        interfaceName = globalInterfaceName
        advertisedVersion = globalAdvertisedVersion
        failure = validationFailure
    }

    package var description: String {
        "global name=\(name) interface=\(interfaceName) "
            + "\(advertisedVersion) rejected: \(failure.description)"
    }
}
