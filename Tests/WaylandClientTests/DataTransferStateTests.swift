import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offer1 = DataOfferID(rawValue: 1)
    private let offer2 = DataOfferID(rawValue: 2)
    private let source1 = DataSourceID(rawValue: 1)
    private let source2 = DataSourceID(rawValue: 2)

    @Test
    func seatAvailabilityRequestsDataDeviceBindingOnce() throws {
        let initial = DataTransferState()

        let first = try initial.reduce(.seatAvailable(seat1))
        #expect(first.effects == [.bindDataDevice(seat1)])
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
    func dataDeviceBoundRequiresKnownSeatAndIsIdempotent() throws {
        let initial = DataTransferState()

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try initial.reduce(.dataDeviceBound(seat1))
        }

        let available = try initial.reduce(.seatAvailable(seat1)).state
        let bound = try available.reduce(.dataDeviceBound(seat1))

        #expect(bound.effects.isEmpty)
        #expect(bound.state.seatSnapshot(seat1)?.hasDataDevice == true)

        let duplicate = try bound.state.reduce(.dataDeviceBound(seat1))
        #expect(duplicate.effects.isEmpty)
        #expect(duplicate.state == bound.state)
    }

    @Test
    func selectionOfferAccumulatesMimeTypesWithoutDuplicates() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state

        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainTextUTF8)).state
        state = try state.reduce(.offerMimeType(id: offer1, mimeType: .plainText)).state

        #expect(
            state.offerSnapshot(offer1)
                == DataOfferSnapshot(
                    id: offer1,
                    role: .selection(seatID: seat1),
                    mimeTypes: [.plainText, .plainTextUTF8]
                )
        )
    }

    @Test
    func offerCreationRejectsUnknownSeatAndDuplicateOffer() throws {
        let initial = DataTransferState()

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try initial.reduce(
                .offerCreated(id: offer1, role: .selection(seatID: seat1))
            )
        }

        let withSeat = try initial.reduce(.seatAvailable(seat1)).state
        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try withSeat.reduce(
                .offerCreated(id: offer1, role: .selection(seatID: seat1))
            )
        }

        let bound = try withSeat.reduce(.dataDeviceBound(seat1)).state
        let withOffer = try bound.reduce(
            .offerCreated(id: offer1, role: .selection(seatID: seat1))
        ).state

        #expect(throws: DataTransferError.duplicateOffer) {
            _ = try withOffer.reduce(
                .offerCreated(id: offer1, role: .selection(seatID: seat1))
            )
        }
    }

    @Test
    func selectionReplacementDestroysPreviousOfferAndPublishesChange() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerCreated(id: offer2, role: .selection(seatID: seat1)))
            .state

        let firstSelection = try state.reduce(
            .selectionChanged(seatID: seat1, offerID: offer1)
        )
        #expect(
            firstSelection.effects
                == [.publishSelectionChanged(seatID: seat1, offerID: offer1)]
        )

        let replacement = try firstSelection.state.reduce(
            .selectionChanged(seatID: seat1, offerID: offer2)
        )
        #expect(
            replacement.effects
                == [
                    .destroyOffer(offer1),
                    .publishSelectionChanged(seatID: seat1, offerID: offer2),
                ]
        )
        #expect(replacement.state.offerSnapshot(offer1) == nil)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionOfferID == offer2)
    }

    @Test
    func clearingSelectionDestroysCurrentOfferAndPublishesNil() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state

        let cleared = try state.reduce(.selectionChanged(seatID: seat1, offerID: nil))

        #expect(
            cleared.effects
                == [
                    .destroyOffer(offer1),
                    .publishSelectionChanged(seatID: seat1, offerID: nil),
                ]
        )
        #expect(cleared.state.offerSnapshot(offer1) == nil)
        #expect(cleared.state.seatSnapshot(seat1)?.selectionOfferID == nil)
    }

    @Test
    func selectionRejectsUnknownSeatAndOffer() throws {
        let initial = DataTransferState()

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try initial.reduce(.selectionChanged(seatID: seat1, offerID: nil))
        }

        let withSeat = try initial.reduce(.seatAvailable(seat1)).state
        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try withSeat.reduce(.selectionChanged(seatID: seat1, offerID: nil))
        }

        let bound = try withSeat.reduce(.dataDeviceBound(seat1)).state

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try bound.reduce(.selectionChanged(seatID: seat1, offerID: offer1))
        }
    }

    @Test
    func sourceReplacementCancelsPreviousSource() throws {
        var state = try boundState(seat1)
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state
        state = try state.reduce(
            .sourceCreated(id: source2, seatID: seat1, mimeTypes: [.plainTextUTF8])
        ).state
        state = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source1))
            .state

        let replacement = try state.reduce(
            .selectionSourceChanged(seatID: seat1, sourceID: source2)
        )

        #expect(
            replacement.effects
                == [.cancelSource(source1), .publishSourceCancelled(source1)]
        )
        #expect(replacement.state.sourceSnapshot(source1) == nil)
        #expect(replacement.state.seatSnapshot(seat1)?.selectionSourceID == source2)
    }

    @Test
    func sourceCancellationClearsSelectionSourceAndPublishesEvent() throws {
        var state = try boundState(seat1)
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state
        state = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source1))
            .state

        let cancelled = try state.reduce(.sourceCancelled(source1))

        #expect(cancelled.effects == [.cancelSource(source1), .publishSourceCancelled(source1)])
        #expect(cancelled.state.sourceSnapshot(source1) == nil)
        #expect(cancelled.state.seatSnapshot(seat1)?.selectionSourceID == nil)
    }

    @Test
    func seatRemovalReleasesDeviceAndCleansSeatScopedResources() throws {
        var state = try DataTransferState()
            .reduce(.seatAvailable(seat1))
            .state
        state = try state.reduce(.dataDeviceBound(seat1)).state
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.dataDeviceBound(seat2)).state
        state = try state.reduce(.offerCreated(id: offer1, role: .selection(seatID: seat1)))
            .state
        state = try state.reduce(.offerCreated(id: offer2, role: .selection(seatID: seat2)))
            .state
        state = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer1)).state
        state = try state.reduce(
            .sourceCreated(id: source1, seatID: seat1, mimeTypes: [.plainText])
        ).state
        state = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: source1))
            .state

        let removed = try state.reduce(.seatRemoved(seat1))

        #expect(
            removed.effects
                == [
                    .releaseDataDevice(seat1),
                    .cancelSource(source1),
                    .publishSourceCancelled(source1),
                ]
        )
        #expect(removed.state.seatSnapshot(seat1) == nil)
        #expect(removed.state.offerSnapshot(offer1) == nil)
        #expect(removed.state.sourceSnapshot(source1) == nil)
        #expect(removed.state.offerSnapshot(offer2) != nil)
        #expect(removed.state.seatSnapshot(seat2) != nil)
    }

    private func boundState(_ seatID: SeatID) throws -> DataTransferState {
        let available = try DataTransferState().reduce(.seatAvailable(seatID)).state
        return try available.reduce(.dataDeviceBound(seatID)).state
    }
}
