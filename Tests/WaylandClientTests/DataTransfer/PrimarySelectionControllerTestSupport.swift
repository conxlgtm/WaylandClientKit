import Foundation
import Glibc
import Synchronization
import WaylandRaw

@testable import WaylandClient

final class RecordingPrimarySelectionBackend: PrimarySelectionControllerBackend {
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

final class RecordingPrimarySelectionDeviceBinding: PrimarySelectionDeviceBinding {
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

final class RecordingPrimarySelectionOfferBinding: PrimarySelectionOfferBinding {
    struct Receive: Equatable {
        let mimeType: MIMEType
        let fd: Int32
    }

    let id: DataOfferID
    var destroyCount = 0
    var receives: [Receive] = []

    private let onEvent: (RawPrimarySelectionOfferEvent) -> Void

    init(
        id offerID: DataOfferID,
        onEvent eventHandler: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) {
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

final class RecordingPrimarySelectionSourceBinding: PrimarySelectionSourceBinding {
    let id: DataSourceID
    var offeredMimeTypes: [MIMEType] = []
    var destroyCount = 0

    private let onEvent: (RawPrimarySelectionSourceEvent) -> Void

    init(
        id sourceID: DataSourceID,
        onEvent eventHandler: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) {
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
    private let storage = Mutex(PrimarySelectionDescriptorIOState())

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

    func writeFileDescriptor(_ descriptor: Int32, bytes: ArraySlice<UInt8>) throws -> Int {
        storage.withLock { storage in
            storage.descriptorWrites.append(
                RecordingPrimarySelectionBackend.DescriptorWrite(
                    descriptor: descriptor,
                    bytes: Array(bytes)
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

private struct PrimarySelectionDescriptorIOState: Sendable {
    var failingCloseDescriptors: [Int32: Int32] = [:]
    var descriptorWrites: [RecordingPrimarySelectionBackend.DescriptorWrite] = []
}

func primarySelectionPayloads(
    _ data: [MIMEType: Data]
) throws -> DataTransferSourcePayloadSet {
    try DataTransferSourcePayloadSet(data: data)
}
