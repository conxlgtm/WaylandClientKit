extension Sequence where Element == RawGlobalAdvertisement {
    package func sortedByGlobalName() -> [RawGlobalAdvertisement] {
        sorted { $0.name < $1.name }
    }

    package func bestGlobal(named interfaceName: String) -> RawGlobalAdvertisement? {
        var selected: RawGlobalAdvertisement?

        for global in self where global.interfaceName == interfaceName {
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
