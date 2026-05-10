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

    package func global(name: UInt32) -> RawGlobalAdvertisement? {
        globalsByName[name]
    }

    package func firstGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        var selected: RawGlobalAdvertisement?
        for global in globalsByName.values where global.interfaceName == interfaceName {
            guard let current = selected else {
                selected = global
                continue
            }

            let hasNewerVersion = global.advertisedVersion > current.advertisedVersion
            let hasEarlierNameAtSameVersion =
                global.advertisedVersion == current.advertisedVersion
                && global.name < current.name
            if hasNewerVersion || hasEarlierNameAtSameVersion {
                selected = global
            }
        }

        return selected
    }
}
