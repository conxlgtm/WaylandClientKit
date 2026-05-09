import Foundation
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let serial = InputSerial(rawValue: 55)

    @Test
    func synchronizingSeatsBindsAndReleasesPrimarySelectionDevices() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)

        try controller.synchronizeSeats([seat2, seat1])
        try controller.synchronizeSeats([seat2])

        #expect(backend.boundSeatIDs == [seat1, seat2])
        #expect(backend.binding(for: seat1)?.releaseCount == 1)
        #expect(backend.binding(for: seat2)?.releaseCount == 0)
    }

    @Test
    func remoteSelectionOfferAccumulatesMimeTypesAndPublishesEvent() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1001)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer("text/plain"))
        offerBinding.emit(.offer("text/plain"))
        offerBinding.emit(.offer("text/plain;charset=utf-8"))
        device.emit(.selection(handle))

        let snapshot = try #require(try controller.offer(for: seat1))

        #expect(snapshot.id == DataOfferID(rawValue: 1))
        #expect(snapshot.role == .selection(seatID: seat1))
        #expect(snapshot.mimeTypes == [.plainText, .plainTextUTF8])
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionChanged(
                        PrimarySelectionEvent(
                            seatID: seat1,
                            offerID: snapshot.id
                        )
                    )
                ]
        )
    }

    @Test
    func receivingPrimarySelectionOfferPassesMimeTypeAndReturnsReadDescriptor() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1002)

        try activateRemoteOffer(handle: handle, controller: controller, backend: backend)

        var descriptor = try controller.receiveOffer(
            id: DataOfferID(rawValue: 1), mimeType: .plainText)
        try descriptor.close()
        let offerBinding = try #require(backend.offerBinding(for: handle))

        #expect(offerBinding.receives == [.init(mimeType: .plainText, fd: 101)])
        #expect(backend.closedDescriptors == [101, 100])
    }

    @Test
    func repeatedRemoteSelectionPreservesActiveOffer() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1004)

        try activateRemoteOffer(handle: handle, controller: controller, backend: backend)
        let device = try #require(backend.binding(for: seat1))
        let offerBinding = try #require(backend.offerBinding(for: handle))

        device.emit(.selection(handle))

        let snapshot = try #require(try controller.offer(for: seat1))
        #expect(snapshot.id == DataOfferID(rawValue: 1))
        #expect(snapshot.mimeTypes == [.plainText])
        #expect(offerBinding.destroyCount == 0)
        #expect(controller.drainDataTransferEvents().isEmpty)
    }

    @Test
    func settingPrimarySelectionSourceOffersMimeTypesAndSetsDeviceSelection() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([
            .plainText: Data("primary".utf8),
            .plainTextUTF8: Data("primary utf8".utf8),
        ])

        try controller.synchronizeSeats([seat1])
        let snapshot = try controller.setSelectionSource(
            seatID: seat1,
            payloads: payloads,
            serial: serial
        )
        let sourceBinding = try #require(backend.sourceBinding(for: snapshot.id))
        let device = try #require(backend.binding(for: seat1))

        #expect(snapshot.seatID == seat1)
        #expect(snapshot.mimeTypes == [.plainText, .plainTextUTF8])
        #expect(sourceBinding.offeredMimeTypes == [.plainText, .plainTextUTF8])
        #expect(device.selections == [.init(sourceID: snapshot.id, serial: serial)])
        #expect(controller.drainDataTransferEvents().isEmpty)
    }

    @Test
    func sourceSendQueuesPrimarySelectionWriteRequest() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])

        try controller.synchronizeSeats([seat1])
        let snapshot = try controller.setSelectionSource(
            seatID: seat1,
            payloads: payloads,
            serial: serial
        )
        try #require(backend.sourceBinding(for: snapshot.id)).emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: 77)
        )

        let requests = controller.drainSourceSendRequests()
        let request = try #require(requests.first)

        #expect(requests.count == 1)
        #expect(request.source == .primarySelection(snapshot.id))
        #expect(request.mimeType == .plainText)
        #expect(request.data == Data("primary".utf8))
    }

    @Test
    func sourceCancellationDestroysBindingAndPublishesSourceCancellation() throws {
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

        sourceBinding.emit(.cancelled)

        #expect(sourceBinding.destroyCount == 1)
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionSourceCancelled(
                        PrimarySelectionSourceIdentity(snapshot.id)
                    )
                ]
        )
        #expect(try controller.offer(for: seat1) == nil)
    }

    @Test
    func shutdownReleasesPrimarySelectionResourcesOnOwnerThread() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1005)

        try controller.synchronizeSeats([seat1, seat2])
        let source = try controller.setSelectionSource(
            seatID: seat1,
            payloads: payloads,
            serial: serial
        )
        try #require(backend.sourceBinding(for: source.id)).emit(
            .send(mimeType: MIMEType.plainText.rawValue, fd: 77)
        )
        let remoteDevice = try #require(backend.binding(for: seat2))
        remoteDevice.emit(.dataOffer(handle))
        let offerBinding = try #require(backend.offerBinding(for: handle))
        offerBinding.emit(.offer(MIMEType.plainText.rawValue))
        remoteDevice.emit(.selection(handle))
        _ = controller.drainDataTransferEvents()

        controller.shutdown()

        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        let firstDevice = try #require(backend.binding(for: seat1))
        let secondDevice = try #require(backend.binding(for: seat2))

        #expect(firstDevice.releaseCount == 1)
        #expect(secondDevice.releaseCount == 1)
        #expect(sourceBinding.destroyCount == 1)
        #expect(offerBinding.destroyCount == 1)
        #expect(backend.closedDescriptors == [77])
        #expect(controller.drainSourceSendRequests().isEmpty)
        #expect(controller.drainDataTransferEvents().isEmpty)
    }

    @Test
    func clearingPrimarySelectionSourceSetsNilSelectionAndDestroysCurrentSource() throws {
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
        let device = try #require(backend.binding(for: seat1))
        _ = controller.drainDataTransferEvents()

        try controller.clearSelectionSource(seatID: seat1, serial: InputSerial(rawValue: 56))

        #expect(sourceBinding.destroyCount == 1)
        #expect(
            device.selections == [
                .init(sourceID: snapshot.id, serial: serial),
                .init(sourceID: nil, serial: InputSerial(rawValue: 56)),
            ]
        )
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionSourceCancelled(
                        PrimarySelectionSourceIdentity(snapshot.id)
                    )
                ]
        )
    }

    func selectingOfferWithoutMimeTypesQueuesCallbackFailure() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let handle = RawPrimarySelectionOfferHandle(uncheckedRawValue: 0x1003)

        try controller.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))
        device.emit(.dataOffer(handle))
        device.emit(.selection(handle))

        #expect(
            throws: DataTransferCallbackFailure(
                context: .primarySelectionDevice(seat1),
                error: .emptyDataOffer
            )
        ) {
            try controller.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func sourceRuntimeBindingIDMustMatchSourceID() throws {
        let backend = RecordingPrimarySelectionBackend()
        backend.sourceBindingIDOverride = DataSourceID(rawValue: 99)
        let controller = PrimarySelectionController(backend: backend)

        try controller.synchronizeSeats([seat1])
        #expect(
            throws: DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                expected: DataSourceID(rawValue: 1),
                actual: DataSourceID(rawValue: 99)
            )
        ) {
            _ = try controller.setSelectionSource(
                seatID: seat1,
                payloads: primarySelectionPayloads([.plainText: Data("primary".utf8)]),
                serial: serial
            )
        }
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
