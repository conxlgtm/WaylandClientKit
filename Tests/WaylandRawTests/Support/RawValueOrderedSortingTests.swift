import Testing

@testable import WaylandRaw

@Suite
struct RawValueOrderedSortingTests {
    @Test
    func rawIDsSortByRawValue() {
        let seatIDs: Set<RawSeatID> = [
            RawSeatID(rawValue: 7),
            RawSeatID(rawValue: 2),
            RawSeatID(rawValue: 5),
        ]

        #expect(seatIDs.sortedByRawValue().map(\.rawValue) == [2, 5, 7])
    }

    @Test
    func rawSnapshotsSortByIDKeyPath() {
        let snapshots = [
            snapshot(id: RawOutputID(rawValue: 4)),
            snapshot(id: RawOutputID(rawValue: 1)),
            snapshot(id: RawOutputID(rawValue: 9)),
        ]

        #expect(snapshots.sortedByRawValue(\.id).map(\.id.rawValue) == [1, 4, 9])
    }

    @Test
    func dictionaryValuesSortByKey() {
        let values = [
            UInt32(3): "third",
            UInt32(1): "first",
            UInt32(2): "second",
        ].valuesSortedByKey()

        #expect(values == ["first", "second", "third"])
    }

    private func snapshot(id: RawOutputID) -> RawOutputSnapshot {
        RawOutputSnapshot(
            id: id,
            version: RawVersion(4),
            geometry: nil,
            logicalGeometry: nil,
            currentMode: nil,
            scale: 1,
            name: nil,
            description: nil
        )
    }
}
