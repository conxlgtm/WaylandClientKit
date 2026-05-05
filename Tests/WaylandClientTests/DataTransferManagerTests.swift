import Synchronization
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0001)
    private let offerHandle2 = RawDataOfferHandle(uncheckedRawValue: 0xDADA_0002)

    @Test
    func synchronizingSeatsBindsNewSeatsInStableOrder() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat2, seat1])

        #expect(backend.boundSeatIDs == [seat1, seat2])
        #expect(
            manager.seatSnapshots
                == [
                    DataTransferSeatSnapshot(
                        seatID: seat1,
                        hasDataDevice: true,
                        selectionOfferID: nil,
                        selectionSourceID: nil
                    ),
                    DataTransferSeatSnapshot(
                        seatID: seat2,
                        hasDataDevice: true,
                        selectionOfferID: nil,
                        selectionSourceID: nil
                    ),
                ]
        )
    }

    @Test
    func synchronizingSameSeatsIsIdempotent() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([seat1])

        #expect(backend.boundSeatIDs == [seat1])
        #expect(backend.binding(for: seat1)?.releaseCount == 0)
    }

    @Test
    func synchronizingRemovedSeatsReleasesDataDevice() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)

        try manager.synchronizeSeats([seat1, seat2])
        let firstBinding = try #require(backend.binding(for: seat1))

        try manager.synchronizeSeats([seat2])

        #expect(firstBinding.releaseCount == 1)
        #expect(manager.seatSnapshots.map(\.seatID) == [seat2])
        #expect(backend.binding(for: seat2)?.releaseCount == 0)
    }

    @Test
    func bindFailureKeepsAlreadyBoundSeats() throws {
        let backend = RecordingDataTransferBackend()
        backend.failingSeatID = seat2
        let manager = DataTransferManager(backend: backend)

        #expect(throws: DataTransferError.unavailable) {
            try manager.synchronizeSeats([seat1, seat2])
        }

        #expect(backend.boundSeatIDs == [seat1, seat2])
        #expect(backend.binding(for: seat1)?.releaseCount == 0)
        #expect(
            manager.seatSnapshots
                == [
                    DataTransferSeatSnapshot(
                        seatID: seat1,
                        hasDataDevice: true,
                        selectionOfferID: nil,
                        selectionSourceID: nil
                    )
                ]
        )
    }

    @Test
    func dataDeviceSelectionClearWithoutCurrentSelectionIsNoOp() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])

        backend.binding(for: seat1)?.emit(.selection(nil))

        #expect(manager.selectionChanges.isEmpty)
    }

    @Test
    func selectionOfferAdoptionTracksMimeTypesAndPublishesSelection() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        offer.emit(.offer(MIMEType.plainText.rawValue))
        offer.emit(.offer(MIMEType.plainTextUTF8.rawValue))
        device.emit(.selection(offerHandle1))

        #expect(
            manager.offerSnapshots
                == [
                    DataOfferSnapshot(
                        id: offer.id,
                        role: .selection(seatID: seat1),
                        mimeTypes: [.plainText, .plainTextUTF8]
                    )
                ]
        )
        #expect(
            manager.selectionChanges
                == [DataTransferSelectionChange(seatID: seat1, offerID: offer.id)]
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    )
                ]
        )
        #expect(manager.drainDataTransferEvents().isEmpty)
    }

    @Test
    func mimeTypeAfterSelectionUpdatesExistingOffer() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        offer.emit(.offer(MIMEType.uriList.rawValue))

        #expect(manager.offerSnapshots.first?.mimeTypes == [.uriList])
    }

    @Test
    func replacingSelectionDestroysPreviousOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let firstOffer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        device.emit(.dataOffer(offerHandle2))
        let secondOffer = try #require(backend.offerBinding(for: offerHandle2))
        device.emit(.selection(offerHandle2))

        #expect(firstOffer.destroyCount == 1)
        #expect(secondOffer.destroyCount == 0)
        #expect(manager.offerSnapshots.map(\.id) == [secondOffer.id])
    }

    @Test
    func clearingSelectionDestroysCurrentOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        device.emit(.selection(offerHandle1))
        device.emit(.selection(nil))

        #expect(offer.destroyCount == 1)
        #expect(manager.offerSnapshots.isEmpty)
        #expect(
            manager.selectionChanges
                == [
                    DataTransferSelectionChange(seatID: seat1, offerID: offer.id),
                    DataTransferSelectionChange(seatID: seat1, offerID: nil),
                ]
        )
        #expect(
            manager.drainDataTransferEvents()
                == [
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: offer.id)
                    ),
                    .selectionChanged(
                        ClipboardSelectionEvent(seatID: seat1, offerID: nil)
                    ),
                ]
        )
    }

    @Test
    func removingSeatDestroysPendingOfferBinding() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.dataOffer(offerHandle1))
        let offer = try #require(backend.offerBinding(for: offerHandle1))
        try manager.synchronizeSeats([])

        #expect(offer.destroyCount == 1)
        #expect(manager.offerSnapshots.isEmpty)
    }

    @Test
    func selectingUnknownOfferReportsCallbackError() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        let device = try #require(backend.binding(for: seat1))

        device.emit(.selection(offerHandle1))

        #expect(throws: DataTransferError.unknownOffer) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func callbackErrorsAreStoredAndThrownOnNextOwnerThreadOperation() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seat1])
        try manager.synchronizeSeats([])
        let releasedBinding = try #require(backend.binding(for: seat1))

        releasedBinding.emit(.selection(nil))

        #expect(throws: DataTransferError.unknownSeat(seat1)) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }
}

final class RecordingDataTransferBackend: DataTransferManagerBackend {
    var boundSeatIDs: [SeatID] = []
    var failingSeatID: SeatID?
    var pipeDescriptors = DataTransferPipeDescriptors(readEnd: 100, writeEnd: 101)
    var pipeCreationCount = 0
    var failingDescriptorAdoptions: Set<Int32> = []
    var failingSourceCreationIDs: Set<DataSourceID> = []
    var closedDescriptors: [Int32] {
        descriptorCloseRecorder.descriptors
    }

    private var bindings: [SeatID: RecordingDataTransferDeviceBinding] = [:]
    private var offerBindingsByHandle: [RawDataOfferHandle: RecordingDataTransferOfferBinding] = [:]
    private var sourceBindings: [DataSourceID: RecordingDataTransferSourceBinding] = [:]
    private let descriptorCloseRecorder = DescriptorCloseRecorder()

    func preconditionIsOwnerThread() {
        // Test backend has no thread-affinity boundary.
    }

    func bindDataDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawDataDeviceEvent) -> Void
    ) throws -> any DataTransferDeviceBinding {
        boundSeatIDs.append(seatID)

        if seatID == failingSeatID {
            throw DataTransferError.unavailable
        }

        let binding = RecordingDataTransferDeviceBinding(
            seatID: seatID,
            onEvent: onEvent
        )
        bindings[seatID] = binding
        return binding
    }

    func adoptDataOffer(
        handle: RawDataOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawDataOfferEvent) -> Void
    ) throws -> any DataTransferOfferBinding {
        let binding = RecordingDataTransferOfferBinding(id: id, onEvent: onEvent)
        offerBindingsByHandle[handle] = binding
        return binding
    }

    func createDataSource(
        id: DataSourceID,
        onEvent: @escaping (RawDataSourceEvent) -> Void
    ) throws -> any DataTransferSourceBinding {
        if failingSourceCreationIDs.contains(id) {
            throw DataTransferError.unavailable
        }

        let binding = RecordingDataTransferSourceBinding(id: id, onEvent: onEvent)
        sourceBindings[id] = binding
        return binding
    }

    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors {
        pipeCreationCount += 1
        return pipeDescriptors
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

    func closeFileDescriptor(_ descriptor: Int32) -> Int32 {
        descriptorCloseRecorder.record(descriptor)
        return 0
    }

    func binding(for seatID: SeatID) -> RecordingDataTransferDeviceBinding? {
        bindings[seatID]
    }

    func offerBinding(for handle: RawDataOfferHandle) -> RecordingDataTransferOfferBinding? {
        offerBindingsByHandle[handle]
    }

    func sourceBinding(for id: DataSourceID) -> RecordingDataTransferSourceBinding? {
        sourceBindings[id]
    }
}

private final class DescriptorCloseRecorder: Sendable {
    private let storage = Mutex<[Int32]>([])

    var descriptors: [Int32] {
        storage.withLock { $0 }
    }

    func record(_ descriptor: Int32) {
        storage.withLock { $0.append(descriptor) }
    }
}

final class RecordingDataTransferDeviceBinding: DataTransferDeviceBinding {
    struct Selection: Equatable {
        let sourceID: DataSourceID?
        let serial: InputSerial
    }

    let seatID: SeatID
    var releaseCount = 0
    var selections: [Selection] = []

    private let onEvent: (RawDataDeviceEvent) -> Void

    init(
        seatID bindingSeatID: SeatID,
        onEvent eventHandler: @escaping (RawDataDeviceEvent) -> Void
    ) {
        seatID = bindingSeatID
        onEvent = eventHandler
    }

    func emit(_ event: RawDataDeviceEvent) {
        onEvent(event)
    }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial) {
        selections.append(Selection(sourceID: source?.id, serial: serial))
    }

    func release() {
        releaseCount += 1
    }
}

final class RecordingDataTransferOfferBinding: DataTransferOfferBinding {
    struct Receive: Equatable {
        let mimeType: MIMEType
        let fd: Int32
    }

    let id: DataOfferID
    var destroyCount = 0
    var receives: [Receive] = []

    private let onEvent: (RawDataOfferEvent) -> Void

    init(id offerID: DataOfferID, onEvent eventHandler: @escaping (RawDataOfferEvent) -> Void) {
        id = offerID
        onEvent = eventHandler
    }

    func emit(_ event: RawDataOfferEvent) {
        onEvent(event)
    }

    func receive(mimeType: MIMEType, fd: Int32) {
        receives.append(Receive(mimeType: mimeType, fd: fd))
    }

    func destroy() {
        destroyCount += 1
    }
}

final class RecordingDataTransferSourceBinding: DataTransferSourceBinding {
    let id: DataSourceID
    var offeredMimeTypes: [MIMEType] = []
    var destroyCount = 0

    private let onEvent: (RawDataSourceEvent) -> Void

    init(id sourceID: DataSourceID, onEvent eventHandler: @escaping (RawDataSourceEvent) -> Void) {
        id = sourceID
        onEvent = eventHandler
    }

    func emit(_ event: RawDataSourceEvent) {
        onEvent(event)
    }

    func offer(mimeType: MIMEType) {
        offeredMimeTypes.append(mimeType)
    }

    func destroy() {
        destroyCount += 1
    }
}
