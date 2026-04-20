public final class RegistryState {
    private var globalsByName: [UInt32: RawGlobalAdvertisement] = [:]

    public init() {}

    public func recordGlobal(name: UInt32, interfaceName: String, version: UInt32) {
        self.globalsByName[name] = RawGlobalAdvertisement(
            name: name,
            interfaceName: interfaceName,
            advertisedVersion: RawVersion(version)
        )
    }

    public func removeGlobal(name: UInt32) {
        self.globalsByName.removeValue(forKey: name)
    }

    public var snapshot: [RawGlobalAdvertisement] {
        self.globalsByName.values.sorted { $0.name < $1.name }
    }

    public func firstGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        self.snapshot.first { $0.interfaceName == interfaceName }
    }
}
