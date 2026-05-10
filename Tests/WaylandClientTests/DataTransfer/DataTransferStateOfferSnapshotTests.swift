import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateOfferSnapshotTests {
    private let seat1 = SeatID(rawValue: 1)
    private let offer1 = DataOfferID(rawValue: 1)

    @Test
    func dataOfferSnapshotRejectsEmptyMIMETypes() {
        #expect(throws: DataTransferError.emptyDataOffer) {
            _ = try DataOfferSnapshot(
                id: offer1,
                role: .selection(seatID: seat1),
                mimeTypes: []
            )
        }
    }

    @Test
    func offerSnapshotsNeverExposePendingOffer() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state

        #expect(state.offerSnapshot(offer1) == nil)
        #expect(state.offerSnapshots.isEmpty)
    }

    @Test
    func pendingOfferPromotesOnlyAfterFirstMIMEType() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(
            state.offerSnapshot(offer1)
                == (try DataOfferSnapshot(
                    id: offer1,
                    role: .selection(seatID: seat1),
                    mimeTypes: [.plainText]
                ))
        )
    }

    @Test
    func duplicateRemoteOfferMIMETypeIsDeduplicatedByPolicy() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(state.offerSnapshot(offer1)?.mimeTypes == [.plainText])
    }

    @Test
    func lateMIMETypeForCurrentSelectionPublishesSelectionChange() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state

        let update = try state.reduce(.offerMimeType(id: offer1, mimeType: .uriList))

        #expect(
            update.effects == [
                .publishSelectionChanged(seatID: seat1, offerID: offer1)
            ]
        )
        #expect(update.state.offerSnapshot(offer1)?.mimeTypes == [.plainText, .uriList])
    }

    @Test
    func duplicateLateMIMETypeForCurrentSelectionDoesNotPublishAgain() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state

        let update = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText))

        #expect(update.effects.isEmpty)
        #expect(update.state.offerSnapshot(offer1)?.mimeTypes == [.plainText])
    }

    private func boundState(_ seatID: SeatID) throws -> DataTransferState {
        let available = try DataTransferState().reduce(.seatAvailable(seatID)).state
        return try available.reduce(.dataDeviceBound(seatID)).state
    }
}
