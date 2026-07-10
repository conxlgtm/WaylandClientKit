package final class RegistryState {
    private var globalsByName: [UInt32: RawGlobalAdvertisement] = [:]
    private var startupGlobalsByInterface: [String: RawGlobalAdvertisement] = [:]
    private var hasFrozenStartupGlobals = false
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

    package func removeGlobal(name: UInt32) -> RawGlobalAdvertisement? {
        globalsByName.removeValue(forKey: name)
    }

    package var snapshot: [RawGlobalAdvertisement] {
        globalsByName.values.sortedByGlobalName()
    }

    package var rejectedGlobals: [RawGlobalAdvertisementRejection] {
        rejectedGlobalsStorage
    }

    package func global(name: UInt32) -> RawGlobalAdvertisement? {
        globalsByName[name]
    }

    package func firstGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        globalsByName.values.bestGlobal(named: interfaceName)
    }

    package func freezeStartupGlobals() {
        guard !hasFrozenStartupGlobals else { return }

        let interfaceNames = Set(globalsByName.values.map(\.interfaceName))
        startupGlobalsByInterface = Dictionary(
            uniqueKeysWithValues: interfaceNames.compactMap { interfaceName in
                firstGlobal(named: interfaceName).map { (interfaceName, $0) }
            }
        )
        hasFrozenStartupGlobals = true
    }

    package func startupGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        guard hasFrozenStartupGlobals else { return nil }
        guard let startupGlobal = startupGlobalsByInterface[interfaceName] else { return nil }
        guard globalsByName[startupGlobal.name] == startupGlobal else { return nil }

        return startupGlobal
    }

    package func wasSelectedAtStartup(_ global: RawGlobalAdvertisement) -> Bool {
        startupGlobalsByInterface[global.interfaceName] == global
    }
}
