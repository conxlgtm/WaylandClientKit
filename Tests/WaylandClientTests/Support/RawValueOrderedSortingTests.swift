import Testing
@testable import WaylandClient

@Suite
struct RawValueOrderedSortingTests {
    @Test
    func sequenceSortsByRawValue() {
        let seatIDs: Set<SeatID> = [
            SeatID(rawValue: 7),
            SeatID(rawValue: 2),
            SeatID(rawValue: 5),
        ]

        #expect(seatIDs.sortedByRawValue().map(\.rawValue) == [2, 5, 7])
    }

    @Test
    func arraySortsInPlaceByRawValue() {
        var offerIDs = [
            DataOfferID(rawValue: 12),
            DataOfferID(rawValue: 3),
            DataOfferID(rawValue: 8),
        ]

        offerIDs.sortByRawValue()

        #expect(offerIDs.map(\.rawValue) == [3, 8, 12])
    }

    @Test
    func sequenceSortsByRawValueKeyPath() {
        let entries = [
            SourceEntry(id: DataSourceID(rawValue: 4)),
            SourceEntry(id: DataSourceID(rawValue: 1)),
            SourceEntry(id: DataSourceID(rawValue: 9)),
        ]

        let sortedEntries = entries.sortedByRawValue(\.id)

        #expect(sortedEntries.map(\.id.rawValue) == [1, 4, 9])
    }

    private struct SourceEntry {
        let id: DataSourceID
    }
}
