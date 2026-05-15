import WaylandRaw

extension SeatStateSnapshot {
    package init(_ raw: RawSeatEventSnapshot) {
        self.init(
            uncheckedAdvertisedCapabilities: SeatCapabilities(
                rawValue: raw.advertisedCapabilities.rawValue
            ),
            activeCapabilities: SeatCapabilities(rawValue: raw.activeCapabilities.rawValue),
            name: raw.name.flatMap(SeatName.init(rawValue:))
        )
    }
}
