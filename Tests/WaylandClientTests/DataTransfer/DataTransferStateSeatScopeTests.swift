import Testing

@testable import WaylandClient

@Suite
struct DataTransferStateSeatScopeTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offer2 = DataOfferID(rawValue: 2)
    private let source2 = DataSourceID(rawValue: 2)

    @Test
    func dragEntryRejectsOfferFromDifferentSeat() throws {
        var state = try availableState(seat1)
        state = try state.reduce(.seatAvailable(seat2)).state
        state = try state.reduce(.dragOfferCreated(id: offer2, seatID: seat2)).state
        state = try state.reduce(.offerMimeType(id: offer2, mimeType: .plainText)).state

        #expect(throws: DataTransferError.unknownOffer) {
            _ = try state.reduce(
                .dragEntered(
                    DataTransferDragEnterTransition(
                        seatID: seat1,
                        offerID: offer2,
                        serial: 1,
                        location: DragLocation(x: 0, y: 0),
                        target: .focusless
                    )
                )
            )
        }
        #expect(state.seatSnapshot(seat1)?.dragAndDropOfferID == nil)
        #expect(state.offerSnapshot(offer2)?.role == .dragAndDrop(seatID: seat2))
    }

    @Test
    func dragSourceCreationRequiresAvailableSeat() throws {
        let state = try availableState(seat1)

        #expect(throws: DataTransferError.unknownSeat(seat2)) {
            _ = try state.reduce(
                .dragSourceCreated(
                    id: source2,
                    seatID: seat2,
                    mimeTypes: [.plainText],
                    actions: [.copy]
                )
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
                        device: .unbound
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
                        role: .dragAndDrop(seatID: seat1),
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
                        role: .dragAndDrop(seatID: seat1),
                        mimeTypes: [.plainText]
                    )
                ],
                sources: [:]
            )
        }
    }

    @Test
    func stateSnapshotInitRejectsSourceKeyMismatch() throws {
        let sourceSnapshot = try dragSourceSnapshot(seatID: seat1)

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
        let sourceSnapshot = try dragSourceSnapshot(seatID: seat1)

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
    func stateSnapshotInitAcceptsDragResourcesForAvailableSeat() throws {
        let offerSnapshot = try DataOfferSnapshot(
            id: offer2,
            role: .dragAndDrop(seatID: seat1),
            mimeTypes: [.plainText],
            dragAndDrop: DragAndDropOfferMetadata(enterSerial: 1)
        )
        let sourceSnapshot = try dragSourceSnapshot(seatID: seat1)

        let state = try DataTransferState(
            seats: [
                seat1: DataTransferSeatSnapshot(
                    seatID: seat1,
                    device: .unbound,
                    dragAndDropOfferID: offer2
                )
            ],
            offers: [offer2: offerSnapshot],
            sources: [source2: sourceSnapshot]
        )

        #expect(state.seatSnapshot(seat1)?.dragAndDropOfferID == offer2)
        #expect(state.offerSnapshot(offer2) == offerSnapshot)
        #expect(state.sourceSnapshot(source2) == sourceSnapshot)
    }

    private func availableState(_ seatID: SeatID) throws -> DataTransferState {
        try DataTransferState().reduce(.seatAvailable(seatID)).state
    }

    private func dragSourceSnapshot(seatID: SeatID) throws -> DataSourceSnapshot {
        try DataSourceSnapshot(
            id: source2,
            role: .dragAndDrop(
                seatID: seatID,
                actions: try DragSourceActions([.copy])
            ),
            mimeTypes: [.plainText]
        )
    }
}
