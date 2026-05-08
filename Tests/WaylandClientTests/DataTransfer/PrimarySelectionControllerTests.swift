import Foundation
import Glibc
import Synchronization
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

        var descriptor = try controller.receiveOffer(id: DataOfferID(rawValue: 1), mimeType: .plainText)
        try descriptor.close()
        let offerBinding = try #require(backend.offerBinding(for: handle))

        #expect(offerBinding.receives == [.init(mimeType: .plainText, fd: 101)])
        #expect(backend.closedDescriptors == [101, 100])
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
                    ),
                    .primarySelectionChanged(
                        PrimarySelectionEvent(seatID: seat1, offerID: nil)
                    ),
                ]
        )
    }

    @Test
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
                context: .dataDevice(seat1),
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

private final class RecordingPrimarySelectionBackend: PrimarySelectionControllerBackend {
    struct DescriptorWrite: Equatable {
        let descriptor: Int32
        let bytes: [UInt8]
    }

    var boundSeatIDs: [SeatID] = []
    var pipeDescriptors = DataTransferPipeDescriptors(readEnd: 100, writeEnd: 101)
    var failingDescriptorAdoptions: Set<Int32> = []
    var sourceBindingIDOverride: DataSourceID?
    var failingCloseDescriptors: [Int32: Int32] {
        get { sourceDescriptorRecorder.failingCloseDescriptors }
        set { sourceDescriptorRecorder.failingCloseDescriptors = newValue }
    }
    var descriptorWrites: [DescriptorWrite] {
        sourceDescriptorRecorder.descriptorWrites
    }
    var closedDescriptors: [Int32] {
        descriptorCloseRecorder.descriptors
    }

    private var bindings: [SeatID: RecordingPrimarySelectionDeviceBinding] = [:]
    private var offerBindingsByHandle:
        [RawPrimarySelectionOfferHandle: RecordingPrimarySelectionOfferBinding] = [:]
    private var sourceBindings: [DataSourceID: RecordingPrimarySelectionSourceBinding] = [:]
    private let descriptorCloseRecorder = PrimarySelectionDescriptorCloseRecorder()
    private lazy var sourceDescriptorRecorder =
        RecordingPrimarySelectionSourceDescriptorIO(closeRecorder: descriptorCloseRecorder)

    func preconditionIsOwnerThread() {
        // Test backend has no thread-affinity boundary.
    }

    func bindPrimarySelectionDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) throws -> any PrimarySelectionDeviceBinding {
        boundSeatIDs.append(seatID)
        let binding = RecordingPrimarySelectionDeviceBinding(
            seatID: seatID,
            onEvent: onEvent
        )
        bindings[seatID] = binding
        return binding
    }

    func adoptPrimarySelectionOffer(
        handle: RawPrimarySelectionOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) throws -> any PrimarySelectionOfferBinding {
        let binding = RecordingPrimarySelectionOfferBinding(id: id, onEvent: onEvent)
        offerBindingsByHandle[handle] = binding
        return binding
    }

    func createPrimarySelectionSource(
        id: DataSourceID,
        onEvent: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) throws -> any PrimarySelectionSourceBinding {
        let binding = RecordingPrimarySelectionSourceBinding(
            id: sourceBindingIDOverride ?? id,
            onEvent: onEvent
        )
        sourceBindings[id] = binding
        return binding
    }

    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors {
        pipeDescriptors
    }

    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor {
        if failingDescriptorAdoptions.contains(descriptor) {
            throw DataTransferError.invalidFileDescriptor(descriptor)
        }

        let recorder = descriptorCloseRecorder
        return try OwnedFileDescriptor(adopting: descriptor) { descriptor in
            recorder.record(descriptor)
            return 0
        }
    }

    var sourceDescriptorIO: DataTransferSourceDescriptorIO {
        sourceDescriptorRecorder.descriptorIO
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        sourceDescriptorRecorder.closeFileDescriptor(descriptor)
    }

    func binding(for seatID: SeatID) -> RecordingPrimarySelectionDeviceBinding? {
        bindings[seatID]
    }

    func offerBinding(
        for handle: RawPrimarySelectionOfferHandle
    ) -> RecordingPrimarySelectionOfferBinding? {
        offerBindingsByHandle[handle]
    }

    func sourceBinding(for id: DataSourceID) -> RecordingPrimarySelectionSourceBinding? {
        sourceBindings[id]
    }
}

private final class RecordingPrimarySelectionDeviceBinding: PrimarySelectionDeviceBinding {
    struct Selection: Equatable {
        let sourceID: DataSourceID?
        let serial: InputSerial
    }

    let seatID: SeatID
    var releaseCount = 0
    var selections: [Selection] = []

    private let onEvent: (RawPrimarySelectionDeviceEvent) -> Void

    init(
        seatID bindingSeatID: SeatID,
        onEvent eventHandler: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) {
        seatID = bindingSeatID
        onEvent = eventHandler
    }

    func emit(_ event: RawPrimarySelectionDeviceEvent) {
        onEvent(event)
    }

    func setSelection(source: (any PrimarySelectionSourceBinding)?, serial: InputSerial) {
        selections.append(Selection(sourceID: source?.id, serial: serial))
    }

    func release() {
        releaseCount += 1
    }
}

private final class RecordingPrimarySelectionOfferBinding: PrimarySelectionOfferBinding {
    struct Receive: Equatable {
        let mimeType: MIMEType
        let fd: Int32
    }

    let id: DataOfferID
    var destroyCount = 0
    var receives: [Receive] = []

    private let onEvent: (RawPrimarySelectionOfferEvent) -> Void

    init(id offerID: DataOfferID, onEvent eventHandler: @escaping (RawPrimarySelectionOfferEvent) -> Void) {
        id = offerID
        onEvent = eventHandler
    }

    func emit(_ event: RawPrimarySelectionOfferEvent) {
        onEvent(event)
    }

    func receive(mimeType: MIMEType, fd: Int32) {
        receives.append(Receive(mimeType: mimeType, fd: fd))
    }

    func destroy() {
        destroyCount += 1
    }
}

private final class RecordingPrimarySelectionSourceBinding: PrimarySelectionSourceBinding {
    let id: DataSourceID
    var offeredMimeTypes: [MIMEType] = []
    var destroyCount = 0

    private let onEvent: (RawPrimarySelectionSourceEvent) -> Void

    init(id sourceID: DataSourceID, onEvent eventHandler: @escaping (RawPrimarySelectionSourceEvent) -> Void) {
        id = sourceID
        onEvent = eventHandler
    }

    func emit(_ event: RawPrimarySelectionSourceEvent) {
        onEvent(event)
    }

    func offer(mimeType: MIMEType) {
        offeredMimeTypes.append(mimeType)
    }

    func destroy() {
        destroyCount += 1
    }
}

private final class PrimarySelectionDescriptorCloseRecorder: Sendable {
    private let storage = Mutex<[Int32]>([])

    var descriptors: [Int32] {
        storage.withLock { $0 }
    }

    func record(_ descriptor: Int32) {
        storage.withLock { $0.append(descriptor) }
    }
}

private final class RecordingPrimarySelectionSourceDescriptorIO: Sendable {
    private let closeRecorder: PrimarySelectionDescriptorCloseRecorder
    private let storage = Mutex(RecordingPrimarySelectionSourceDescriptorIOState())

    init(closeRecorder descriptorCloseRecorder: PrimarySelectionDescriptorCloseRecorder) {
        closeRecorder = descriptorCloseRecorder
    }

    var descriptorIO: DataTransferSourceDescriptorIO {
        DataTransferSourceDescriptorIO(
            prepareDescriptorForWriting: { _ in return },
            writeDescriptor: { descriptor, bytes in
                try self.writeFileDescriptor(descriptor, bytes: bytes)
            },
            closeDescriptor: { descriptor in
                self.closeFileDescriptor(descriptor)
            }
        )
    }

    var failingCloseDescriptors: [Int32: Int32] {
        get { storage.withLock(\.failingCloseDescriptors) }
        set { storage.withLock { $0.failingCloseDescriptors = newValue } }
    }

    var descriptorWrites: [RecordingPrimarySelectionBackend.DescriptorWrite] {
        storage.withLock(\.descriptorWrites)
    }

    func writeFileDescriptor(_ descriptor: Int32, bytes: [UInt8]) throws -> Int {
        storage.withLock { storage in
            storage.descriptorWrites.append(
                RecordingPrimarySelectionBackend.DescriptorWrite(
                    descriptor: descriptor,
                    bytes: bytes
                )
            )
            return bytes.count
        }
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        closeRecorder.record(descriptor)
        guard let closeErrno = storage.withLock(\.failingCloseDescriptors)[descriptor] else {
            return .closed
        }

        return .failed(WaylandSystemErrno(unchecked: closeErrno > 0 ? closeErrno : EIO))
    }
}

private struct RecordingPrimarySelectionSourceDescriptorIOState: Sendable {
    var failingCloseDescriptors: [Int32: Int32] = [:]
    var descriptorWrites: [RecordingPrimarySelectionBackend.DescriptorWrite] = []
}

private func primarySelectionPayloads(
    _ data: [MIMEType: Data]
) throws -> DataTransferSourcePayloadSet {
    try DataTransferSourcePayloadSet(data: data)
}
