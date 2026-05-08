import Foundation
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerSelectionEventTests {
    private let seat1 = SeatID(rawValue: 1)
    private let serial = InputSerial(rawValue: 55)

    @Test
    func clearingEmptyPrimarySelectionDoesNotPublishChangeEvent() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        try controller.clearSelectionSource(seatID: seat1, serial: serial)
        try controller.clearSelectionSource(seatID: seat1, serial: InputSerial(rawValue: 56))

        #expect(
            device.selections == [
                .init(sourceID: nil, serial: serial),
                .init(sourceID: nil, serial: InputSerial(rawValue: 56)),
            ]
        )
        #expect(controller.drainDataTransferEvents().isEmpty)
    }

    @Test
    func nilSelectionCallbackPublishesChangeOnlyAfterActiveSelection() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1005)

        try activateRemoteOffer(handle: handle, controller: controller, backend: backend)
        let device = try #require(backend.binding(for: seat1))
        let offerBinding = try #require(backend.offerBinding(for: handle))

        device.emit(.selection(nil))
        device.emit(.selection(nil))

        #expect(offerBinding.destroyCount == 1)
        #expect(try controller.offer(for: seat1) == nil)
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionChanged(
                        PrimarySelectionEvent(seatID: seat1, offerID: nil)
                    )
                ]
        )
    }

    @Test
    func sourceCancelledAfterLocalClearDoesNotPublishSecondCancellation() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])

        try controller.synchronizeSeats([seat1])
        let snapshot = try controller.setSelectionSource(
            seatID: seat1,
            payloads: payloads,
            serial: serial
        )
        let sourceBinding = try #require(backend.sourceBinding(for: snapshot.id))
        _ = controller.drainDataTransferEvents()

        try controller.clearSelectionSource(seatID: seat1, serial: InputSerial(rawValue: 56))
        sourceBinding.emit(.cancelled)

        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionSourceCancelled(
                        PrimarySelectionSourceIdentity(snapshot.id)
                    )
                ]
        )
    }

    private func activateRemoteOffer(
        handle: RawPrimarySelectionOfferHandle,
        controller: PrimarySelectionController,
        backend: RecordingPrimarySelectionBackend
    ) throws {
        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        try #require(backend.offerBinding(for: handle)).emit(.offer(MIMEType.plainText.rawValue))
        device.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()
    }
}
