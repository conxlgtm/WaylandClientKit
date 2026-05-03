package final class RegistryState {
    private var globalsByName: [UInt32: RawGlobalAdvertisement] = [:]

    package func recordGlobal(name: UInt32, interfaceName: String, version: UInt32) {
        globalsByName[name] = RawGlobalAdvertisement(
            name: name,
            interfaceName: interfaceName,
            advertisedVersion: RawVersion(version)
        )
    }

    package func removeGlobal(name: UInt32) {
        globalsByName.removeValue(forKey: name)
    }

    package var snapshot: [RawGlobalAdvertisement] {
        globalsByName.values.sorted { $0.name < $1.name }
    }

    package func firstGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        snapshot.first { $0.interfaceName == interfaceName }
    }
}
