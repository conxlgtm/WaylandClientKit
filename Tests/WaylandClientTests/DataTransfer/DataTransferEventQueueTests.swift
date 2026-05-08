import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferEventQueueTests {
    private let seat1 = SeatID(rawValue: 1)
    private let clipboardOfferHandle = RawDataOfferHandle(uncheckedRawValue: 0xE000_0001)
    private let primarySelectionOfferHandle =
        RawPrimarySelectionOfferHandle(uncheckedRawValue: 0xE000_0002)

    @Test
    func sharedQueuePreservesCallbackOrderAcrossClipboardAndPrimarySelection() throws {
        let eventQueue = DataTransferEventQueue()
        let clipboardBackend = RecordingDataTransferBackend()
        let primaryBackend = RecordingPrimarySelectionBackend()
        let clipboardManager = DataTransferManager(
            backend: clipboardBackend,
            eventQueue: eventQueue
        )
        let primaryController = PrimarySelectionController(
            backend: primaryBackend,
            eventQueue: eventQueue
        )

        try clipboardManager.synchronizeSeats([seat1])
        try primaryController.synchronizeSeats([seat1])

        let primaryDevice = try #require(primaryBackend.binding(for: seat1))
        primaryDevice.emit(.dataOffer(primarySelectionOfferHandle))
        try #require(primaryBackend.offerBinding(for: primarySelectionOfferHandle))
            .emit(.offer(MIMEType.plainText.rawValue))
        primaryDevice.emit(.selection(primarySelectionOfferHandle))

        let clipboardDevice = try #require(clipboardBackend.binding(for: seat1))
        clipboardDevice.emit(.dataOffer(clipboardOfferHandle))
        try #require(clipboardBackend.offerBinding(for: clipboardOfferHandle))
            .emit(.offer(MIMEType.plainText.rawValue))
        clipboardDevice.emit(.selection(clipboardOfferHandle))

        #expect(
            eventQueue.drain()
                == [
                    .primarySelectionChanged(
                        PrimarySelectionEvent(
                            seatID: seat1,
                            offerID: DataOfferID(rawValue: 1)
                        )
                    ),
                    .clipboardSelectionChanged(
                        ClipboardSelectionEvent(
                            seatID: seat1,
                            offerID: DataOfferID(rawValue: 1)
                        )
                    ),
                ]
        )
        #expect(eventQueue.drain().isEmpty)
    }
}
