import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateSelectionTests {
    private let seat1 = SeatID(rawValue: 1)
    private let offer1 = DataOfferID(rawValue: 1)
    private let source1 = DataSourceID(rawValue: 1)

    @Test
    func remoteSelectionDisplacesOwnedSource() throws {
        var state = try boundState(seat1)
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state
        state = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source1))
            .state
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        let replacement = try state.reduce(
            .selectionChanged(seatID: seat1, offerID: offer1)
        )

        #expect(
            replacement.effects
                == [
                    .cancelSource(source1),
                    .publishSourceCancelled(source1),
                    .publishSelectionChanged(seatID: seat1, offerID: offer1),
                ]
        )
        #expect(replacement.state.sourceSnapshot(source1) == nil)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionOfferID == offer1)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionSourceID == nil)
    }

    @Test
    func ownedSourceDisplacesRemoteOffer() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state

        let replacement = try state.reduce(
            .selectionSourceChanged(seatID: seat1, sourceID: source1)
        )

        #expect(replacement.effects == [.destroyOffer(offer1)])
        #expect(replacement.state.offerSnapshot(offer1) == nil)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionOfferID == nil)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionSourceID == source1)
    }

    @Test
    func sourceCancelledAfterRemoteReplacementDoesNotDisturbSelectionOffer() throws {
        var state = try boundState(seat1)
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state
        state = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source1))
            .state
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state

        let cancelled = try state.reduce(.sourceCancelled(source1))

        #expect(cancelled.effects.isEmpty)
        #expect(cancelled.state.seatSnapshot(seat1)?.selectionOfferID == offer1)
        #expect(cancelled.state.seatSnapshot(seat1)?.selectionSourceID == nil)
    }

    private func boundState(_ seatID: SeatID) throws -> DataTransferState {
        let available = try DataTransferState().reduce(.seatAvailable(seatID)).state
        return try available.reduce(.dataDeviceBound(seatID)).state
    }
}
