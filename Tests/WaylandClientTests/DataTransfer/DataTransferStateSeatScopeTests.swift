import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateSeatScopeTests {  // swiftlint:disable:this type_body_length
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offer2 = DataOfferID(rawValue: 2)
    private let source2 = DataSourceID(rawValue: 2)

    @Test
    func selectionRejectsOfferFromDifferentSeat() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.dataDeviceBound(seat2)).state
        state = try state.reduce(.offerCreated(id: offer2, role: .selection(seatID: seat2)))
            .state
        state = try state.reduce(.offerMimeType(id: offer2, mimeType: .plainText)).state

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer2))
        }
        #expect(state.seatSnapshot(seat1)?.selectionOfferID == nil)
        #expect(state.offerSnapshot(offer2)?.role == .selection(seatID: seat2))
    }

    @Test
    func selectionRejectsDragAndDropOffer() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.offerCreated(id: offer2, role: .dragAndDrop(seatID: seat1)))
            .state
        state = try state.reduce(.offerMimeType(id: offer2, mimeType: .plainText)).state

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try state.reduce(.selectionChanged(seatID: seat1, offerID: offer2))
        }
        #expect(state.seatSnapshot(seat1)?.selectionOfferID == nil)
        #expect(state.offerSnapshot(offer2)?.role == .dragAndDrop(seatID: seat1))
    }

    @Test
    func selectionSourceRejectsSourceFromDifferentSeat() throws {
        var state = try boundState(seat1)
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.dataDeviceBound(seat2)).state
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
    func selectionRejectedBeforeDataDeviceBound() throws {
        let state = try DataTransferState()
            .reduce(.seatAvailable(seat1))
            .state

        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try state.reduce(.selectionChanged(seatID: seat1, offerID: nil))
        }
        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try state.reduce(.offerCreated(id: offer2, role: .selection(seatID: seat1)))
        }
    }

    @Test
    func sourceSelectionRejectedBeforeDataDeviceBound() throws {
        let state = try DataTransferState()
            .reduce(.seatAvailable(seat1))
            .state

        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try state.reduce(
                .sourceCreated(id: source2, seatID: seat1, mimeTypes: [.plainText])
            )
        }
        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try state.reduce(.selectionSourceChanged(seatID: seat1, sourceID: nil))
        }
    }

    @Test
    func stateSnapshotInitRejectsForeignSeatOffer() {
        #expect(throws: DataTransferError.unknownOffer) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .remoteOffer(offer2))
                    ),
                    seat2: DataTransferSeatSnapshot(
                        seatID: seat2,
                        device: .bound(selection: .none)
                    ),
                ],
                offers: [
                    offer2: try DataOfferSnapshot(
                        id: offer2,
                        role: .selection(seatID: seat2),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSelectionOfferWithDragAndDropRole() {
        #expect(throws: DataTransferError.unknownOffer) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .remoteOffer(offer2))
                    )
                ],
                offers: [
                    offer2: try DataOfferSnapshot(
                        id: offer2,
                        role: .dragAndDrop(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsDanglingSelectionOffer() {
        #expect(throws: DataTransferError.unknownOffer) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .remoteOffer(offer2))
                    )
                ],
                offers: [:],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSelectionOfferWithoutMimeTypes() {
        #expect(throws: DataTransferError.emptyDataOffer) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .remoteOffer(offer2))
                    )
                ],
                offers: [
                    offer2: try DataOfferSnapshot(
                        id: offer2,
                        role: .selection(seatID: seat1),
                        mimeTypes: []
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsDanglingSelectionSource() {
        #expect(throws: DataTransferError.unknownSource) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .bound(selection: .ownedSource(source2))
                    )
                ],
                offers: [:],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSeatKeyMismatch() {
        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat2,
                        device: .bound(selection: .none)
                    )
                ]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsOfferKeyMismatch() {
        #expect(throws: DataTransferError.unknownOffer) {
            _ = try DataTransferState(
                seats: [:],
                offers: [
                    DataOfferID(rawValue: 1): try DataOfferSnapshot(
                        id: offer2,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsOfferForUnknownSeat() {
        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try DataTransferState(
                seats: [:],
                offers: [
                    offer2: try DataOfferSnapshot(
                        id: offer2,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsOfferForSeatWithoutDataDevice() {
        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .unbound
                    )
                ],
                offers: [
                    offer2: try DataOfferSnapshot(
                        id: offer2,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSourceKeyMismatch() throws {
        let sourceSnapshot = try DataSourceSnapshot(
            id: source2,
            seatID: seat1,
            mimeTypes: [.plainText]
        )

        #expect(throws: DataTransferError.unknownSource) {
            _ = try DataTransferState(
                seats: [:],
                offers: [:],
                sources: [
                    DataSourceID(rawValue: 1): sourceSnapshot
                ]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSourceForUnknownSeat() throws {
        let sourceSnapshot = try DataSourceSnapshot(
            id: source2,
            seatID: seat1,
            mimeTypes: [.plainText]
        )

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            _ = try DataTransferState(
                seats: [:],
                offers: [:],
                sources: [
                    source2: sourceSnapshot
                ]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSourceForSeatWithoutDataDevice() throws {
        let sourceSnapshot = try DataSourceSnapshot(
            id: source2,
            seatID: seat1,
            mimeTypes: [.plainText]
        )

        #expect(throws: DataTransferError.missingDataDevice(seat1)) {
            _ = try DataTransferState(
                seats: [
                    seat1: DataTransferSeatSnapshot(
                        seatID: seat1,
                        device: .unbound
                    )
                ],
                offers: [:],
                sources: [
                    source2: sourceSnapshot
                ]
            )
        }
    }

    private func boundState(_ seatID: SeatID) throws -> DataTransferState {
        let available = try DataTransferState().reduce(.seatAvailable(seatID)).state
        return try available.reduce(.dataDeviceBound(seatID)).state
    }
}
