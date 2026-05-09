import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerRemoteOfferTests {
    private let seat1 = SeatID(rawValue: 1)

    @Test
    func malformedRemotePrimarySelectionMIMETypeIsIgnored() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1006)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer("UTF8_STRING"))
        offerBinding.emit(.offer(" text/plain "))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(handle))

        let snapshot = try #require(try controller.offer(for: seat1))
        #expect(snapshot.mimeTypes == [.plainText])
        try controller.throwPendingCallbackErrorIfAny()
    }

    @Test
    func mimeTypeAfterPrimarySelectionUpdatesExistingOffer() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1007)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()
        offerBinding.emit(.offer(MIMEType.uriList.rawValue))

        let snapshot = try #require(try controller.offer(for: seat1))

        #expect(snapshot.id == DataOfferID(rawValue: 1))
        #expect(snapshot.mimeTypes == [.plainText, .uriList])
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionChanged(
                        PrimarySelectionEvent(seatID: seat1, offerID: snapshot.id)
                    )
                ]
        )
    }

    @Test
    func duplicateMimeTypeAfterPrimarySelectionDoesNotPublishDuplicateEvent() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1008)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()

        offerBinding.emit(.offer(MIMEType.plainText.rawValue))

        let snapshot = try #require(try controller.offer(for: seat1))
        #expect(snapshot.mimeTypes == [.plainText])
        #expect(controller.drainDataTransferEvents().isEmpty)
    }

    @Test
    func malformedMimeTypeAfterPrimarySelectionDoesNotPublishOrRecordFailure() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1009)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()

        offerBinding.emit(.offer("UTF8_STRING"))
        offerBinding.emit(.offer(" text/uri-list "))

        let snapshot = try #require(try controller.offer(for: seat1))
        #expect(snapshot.mimeTypes == [.plainText])
        #expect(controller.drainDataTransferEvents().isEmpty)
        try controller.throwPendingCallbackErrorIfAny()
    }
}
