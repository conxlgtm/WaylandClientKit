import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateSeatScopeTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offer2 = DataOfferID(rawValue: 2)
    private let source2 = DataSourceID(rawValue: 2)

    @Test
    func selectionRejectsOfferFromDifferentSeat() throws {
        var state = try DataTransferState()
            .reduce(.seatAvailable(seat1))
            .state
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.offerCreated(id: offer2, role: .selection(seatID: seat2)))
            .state

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer2))
        }
        #expect(state.seatSnapshot(seat1)?.selectionOfferID == nil)
        #expect(state.offerSnapshot(offer2)?.role == .selection(seatID: seat2))
    }

    @Test
    func selectionSourceRejectsSourceFromDifferentSeat() throws {
        var state = try DataTransferState()
            .reduce(.seatAvailable(seat1))
            .state
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(
            .sourceCreated(id: source2, seatID: seat2, mimeTypes: [.plainText])
        ).state

        #expect(throws: DataTransferError.unknownSource) {
            _ = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source2))
        }
        #expect(state.seatSnapshot(seat1)?.selectionSourceID == nil)
        #expect(state.sourceSnapshot(source2)?.seatID == seat2)
    }

    @Test
    func seatRemovalDoesNotCleanOrPublishForeignSeatSelection() throws {
        let state = DataTransferState(
            seats: [
                seat1: DataTransferSeatSnapshot(
                    seatID: seat1,
                    hasDataDevice: true,
                    selectionOfferID: offer2,
                    selectionSourceID: source2
                ),
                seat2: DataTransferSeatSnapshot(
                    seatID: seat2,
                    hasDataDevice: true,
                    selectionOfferID: nil,
                    selectionSourceID: nil
                ),
            ],
            offers: [
                offer2: DataOfferSnapshot(
                    id: offer2,
                    role: .selection(seatID: seat2),
                    mimeTypes: [.plainText]
                )
            ],
            sources: [
                source2: DataSourceSnapshot(
                    id: source2,
                    seatID: seat2,
                    mimeTypes: [.plainText]
                )
            ]
        )

        let removed = try state.reduce(.seatRemoved(seat1))

        #expect(removed.effects == [.releaseDataDevice(seat1)])
        #expect(removed.state.seatSnapshot(seat1) == nil)
        #expect(removed.state.seatSnapshot(seat2) != nil)
        #expect(removed.state.offerSnapshot(offer2) != nil)
        #expect(removed.state.sourceSnapshot(source2) != nil)
    }
}
