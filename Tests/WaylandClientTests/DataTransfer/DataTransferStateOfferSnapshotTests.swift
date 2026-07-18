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
                role: .dragAndDrop(seatID: seat1),
                mimeTypes: []
            )
        }
    }

    @Test
    func offerSnapshotsNeverExposePendingDragOffer() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state

        #expect(state.offerSnapshot(offer1) == nil)
        #expect(state.offerSnapshots.isEmpty)
    }

    @Test
    func pendingDragOfferPromotesOnlyAfterFirstMIMEType() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(
            state.offerSnapshot(offer1)
                == (try DataOfferSnapshot(
                    id: offer1,
                    role: .dragAndDrop(seatID: seat1),
                    mimeTypes: [.plainText]
                ))
        )
    }

    @Test
    func duplicateDragOfferMIMETypeIsDeduplicatedByPolicy() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(state.offerSnapshot(offer1)?.mimeTypes == [.plainText])
    }

    @Test
    func lateMIMETypeForActiveDragOfferPublishesChange() throws {
        let state = try activeDragState()

        let update = try state.reduce(.offerMimeType(id: offer1, mimeType: .uriList))

        #expect(
            update.effects == [
                .publishDragOfferChanged(seatID: seat1, offerID: offer1)
            ]
        )
        #expect(update.state.offerSnapshot(offer1)?.mimeTypes == [.plainText, .uriList])
    }

    @Test
    func duplicateLateMIMETypeForActiveDragOfferDoesNotPublishAgain() throws {
        let state = try activeDragState()

        let update = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText))

        #expect(update.effects.isEmpty)
        #expect(update.state.offerSnapshot(offer1)?.mimeTypes == [.plainText])
    }

    private func availableState(_ seatID: SeatID) throws -> DataTransferState {
        try DataTransferState().reduce(.seatAvailable(seatID)).state
    }

    private func activeDragState() throws -> DataTransferState {
        var state = try availableState(seat1)
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        return try state.reduce(
            .dragEntered(
                DataTransferDragEnterTransition(
                    seatID: seat1,
                    offerID: offer1,
                    serial: 1,
                    location: DragLocation(x: 0, y: 0),
                    target: .focusless
                )
            )
        ).state
    }
}
