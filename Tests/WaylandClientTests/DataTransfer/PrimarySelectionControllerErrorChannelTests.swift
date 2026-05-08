import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerErrorChannelTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)

    @Test
    func mismatchedPendingOfferSeatReportsPrimarySelectionOfferIdentity() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1004)

        try controller.synchronizeSeats([seat1, seat2])
        let firstDevice = try #require(backend.binding(for: seat1))
        let secondDevice = try #require(backend.binding(for: seat2))
        firstDevice.emit(.dataOffer(handle))
        try #require(backend.offerBinding(for: handle)).emit(.offer(MIMEType.plainText.rawValue))
        secondDevice.emit(.selection(handle))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .primarySelectionDevice(seat2),
                error: .mismatchedOfferSeat(
                    offer: .primarySelection(
                        PrimarySelectionOfferIdentity(DataOfferID(rawValue: 1))
                    ),
                    expected: seat2,
                    actual: seat1
                )
            )
        ) {
            try controller.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func mismatchedActiveOfferSeatReportsPrimarySelectionOfferIdentity() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1005)

        try controller.synchronizeSeats([seat1, seat2])
        let firstDevice = try #require(backend.binding(for: seat1))
        let secondDevice = try #require(backend.binding(for: seat2))
        firstDevice.emit(.dataOffer(handle))
        try #require(backend.offerBinding(for: handle)).emit(.offer(MIMEType.plainText.rawValue))
        firstDevice.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()

        secondDevice.emit(.selection(handle))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .primarySelectionDevice(seat2),
                error: .mismatchedOfferSeat(
                    offer: .primarySelection(
                        PrimarySelectionOfferIdentity(DataOfferID(rawValue: 1))
                    ),
                    expected: seat2,
                    actual: seat1
                )
            )
        ) {
            try controller.throwPendingCallbackErrorIfAny()
        }
    }
}
