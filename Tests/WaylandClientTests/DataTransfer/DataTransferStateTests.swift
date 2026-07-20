import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offer1 = DataOfferID(rawValue: 1)
    private let offer2 = DataOfferID(rawValue: 2)
    private let offer3 = DataOfferID(rawValue: 3)
    private let source1 = DataSourceID(rawValue: 1)
    private let source2 = DataSourceID(rawValue: 2)
    private let source3 = DataSourceID(rawValue: 3)

    @Test
    func seatAvailabilityAddsSeatOnce() throws {
        let initial = DataTransferState()

        let first = try initial.reduce(.seatAvailable(seat1))
        #expect(first.effects.isEmpty)
        #expect(
            first.state.seatSnapshot(seat1)
                == DataTransferSeatSnapshot(
                    seatID: seat1,
                    device: .unbound
                )
        )

        let second = try first.state.reduce(.seatAvailable(seat1))
        #expect(second.effects.isEmpty)
        #expect(second.state == first.state)
    }

    @Test
    func dragOfferAccumulatesMIMETypesWithoutDuplicates() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainTextUTF8)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(
            state.offerSnapshot(offer1)
                == (try DataOfferSnapshot(
                    id: offer1,
                    role: .dragAndDrop(seatID: seat1),
                    mimeTypes: [.plainText, .plainTextUTF8]
                ))
        )
    }

    @Test
    func dragOfferCreationRejectsUnknownSeatAndDuplicateOffer() throws {
        let initial = DataTransferState()

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try initial.reduce(.dragOfferCreated(id: offer1, seatID: seat1))
        }

        let available = try initial.reduce(.seatAvailable(seat1)).state
        let withOffer = try available.reduce(
            .dragOfferCreated(id: offer1, seatID: seat1)
        ).state

        #expect(throws: DataTransferError.duplicateOffer) {
            _ = try withOffer.reduce(.dragOfferCreated(id: offer1, seatID: seat1))
        }
    }

    @Test
    func actionBatchDiscardsEarlierChangesWhenALaterActionFails() throws {
        let state = try availableState(seat1)

        #expect(throws: DataTransferError.duplicateOffer) {
            _ = try state.reduce([
                .dragOfferCreated(id: offer1, seatID: seat1),
                .dragOfferCreated(id: offer1, seatID: seat1),
            ])
        }

        #expect(state.offerSnapshots.isEmpty)
        let created = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1))
        #expect(created.effects.isEmpty)
    }

    @Test
    func dragSourceCancellationRemovesSourceAndPublishesEvent() throws {
        var state = try availableState(seat1)
        state = try state.reduce(
            .dragSourceCreated(
                id: source1,
                seatID: seat1,
                mimeTypes: [.plainText],
                actions: [.copy]
            )
        ).state

        let cancelled = try state.reduce(.sourceCancelled(source1))

        #expect(
            cancelled.effects
                == [.cancelSource(source1), .publishDragSourceCancelled(source1)]
        )
        #expect(cancelled.state.sourceSnapshot(source1) == nil)
    }

    @Test
    func seatRemovalCleansDragResourcesWithoutAffectingOtherSeats() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.dragOfferCreated(id: offer1, seatID: seat1)).state
        state = try state.reduce(.dragOfferCreated(id: offer2, seatID: seat1)).state
        state = try state.reduce(.dragOfferCreated(id: offer3, seatID: seat2)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.offerMimeType(id: offer2, mimeType: .plainTextUTF8)).state
        state = try state.reduce(.offerMimeType(id: offer3, mimeType: .uriList)).state
        state = try state.reduce(
            .dragSourceCreated(
                id: source1,
                seatID: seat1,
                mimeTypes: [.plainText],
                actions: [.copy]
            )
        ).state
        state = try state.reduce(
            .dragSourceCreated(
                id: source2,
                seatID: seat1,
                mimeTypes: [.plainTextUTF8],
                actions: [.move]
            )
        ).state
        state = try state.reduce(
            .dragSourceCreated(
                id: source3,
                seatID: seat2,
                mimeTypes: [.uriList],
                actions: [.copy]
            )
        ).state

        let removed = try state.reduce(.seatRemoved(seat1))

        #expect(
            removed.effects
                == [
                    .destroyOffer(offer1),
                    .destroyOffer(offer2),
                    .cancelSource(source1),
                    .publishDragSourceCancelled(source1),
                    .cancelSource(source2),
                    .publishDragSourceCancelled(source2),
                ]
        )
        #expect(removed.state.seatSnapshot(seat1) == nil)
        #expect(removed.state.offerSnapshot(offer1) == nil)
        #expect(removed.state.offerSnapshot(offer2) == nil)
        #expect(removed.state.sourceSnapshot(source1) == nil)
        #expect(removed.state.sourceSnapshot(source2) == nil)
        #expect(removed.state.seatSnapshot(seat2) != nil)
        #expect(removed.state.offerSnapshot(offer3) != nil)
        #expect(removed.state.sourceSnapshot(source3) != nil)

        let duplicateRemoval = try removed.state.reduce(.seatRemoved(seat1))
        #expect(duplicateRemoval.effects.isEmpty)
        #expect(duplicateRemoval.state == removed.state)
    }

    private func availableState(_ seatID: SeatID) throws -> DataTransferState {
        try DataTransferState().reduce(.seatAvailable(seatID)).state
    }
}
