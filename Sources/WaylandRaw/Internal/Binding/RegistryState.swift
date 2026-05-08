package final class RegistryState {
    private var globalsByName: [UInt32: RawGlobalAdvertisement] = [:]
    private var rejectedGlobalsStorage: [RawGlobalAdvertisementRejection] = []

    @discardableResult
    package func recordGlobal(name: UInt32, interfaceName: String, version: UInt32) -> Bool {
        let advertisedVersion = RawVersion(version)
        if let failure = RawGlobalAdvertisement.validationFailure(
            interfaceName: interfaceName,
            advertisedVersion: advertisedVersion
        ) {
            rejectedGlobalsStorage.append(
                RawGlobalAdvertisementRejection(
                    name: name,
                    interfaceName: interfaceName,
                    advertisedVersion: advertisedVersion,
                    failure: failure
                )
            )
            return false
        }

        guard
            let advertisement = RawGlobalAdvertisement(
                name: name,
                interfaceName: interfaceName,
                advertisedVersion: advertisedVersion
            )
        else {
            preconditionFailure("validated registry global failed construction")
        }

        globalsByName[name] = advertisement
        return true
    }

    package func removeGlobal(name: UInt32) {
        globalsByName.removeValue(forKey: name)
    }

    package var snapshot: [RawGlobalAdvertisement] {
        globalsByName.values.sorted { $0.name < $1.name }
    }

    package var rejectedGlobals: [RawGlobalAdvertisementRejection] {
        rejectedGlobalsStorage
    }

    package func firstGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        snapshot.first { $0.interfaceName == interfaceName }
    }
}
