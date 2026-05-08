public struct SeatStateSnapshot: Equatable, Sendable {
    public let advertisedCapabilities: SeatCapabilities
    public let activeCapabilities: SeatCapabilities
    public let name: SeatName?

    public init(
        advertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        name seatName: SeatName?
    ) throws {
        guard seatActiveCapabilities.isSubset(of: seatAdvertisedCapabilities) else {
            throw SeatStateSnapshotError.activeCapabilityNotAdvertised(
                activeCapabilities: seatActiveCapabilities,
                advertisedCapabilities: seatAdvertisedCapabilities
            )
        }

        self.init(
            uncheckedAdvertisedCapabilities: seatAdvertisedCapabilities,
            activeCapabilities: seatActiveCapabilities,
            name: seatName
        )
    }

    package init(
        uncheckedAdvertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        name seatName: SeatName?
    ) {
        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities = seatActiveCapabilities
        name = seatName
    }
}

public enum SeatStateSnapshotError: Error, Equatable, Sendable {
    case activeCapabilityNotAdvertised(
        activeCapabilities: SeatCapabilities,
        advertisedCapabilities: SeatCapabilities
    )
}
