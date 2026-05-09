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
}
