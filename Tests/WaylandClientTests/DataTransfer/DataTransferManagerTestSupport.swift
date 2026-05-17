import Foundation
import Synchronization
import WaylandRaw

@testable import WaylandClient

final class RecordingDataTransferBackend: DataTransferManagerBackend {
    struct DescriptorWrite: Equatable {
        let descriptor: Int32
        let bytes: [UInt8]
    }

    var boundSeatIDs: [SeatID] = []
    var failingSeatID: SeatID?
    var pipeDescriptors = DataTransferPipeDescriptors(readEnd: 100, writeEnd: 101)
    var pipeCreationCount = 0
    var failingDescriptorAdoptions: Set<Int32> = []
    var failingSourceCreationIDs: Set<DataSourceID> = []
    var preparedDragIcons: [DragIcon] = []
    var failingDragIcon: DragIcon?
    var sourceBindingIDOverride: DataSourceID?
    var sourceBindingProtocolVersion: RawVersion = 3
    var failingWriteDescriptors: [Int32: DataTransferError] {
        get { sourceDescriptorRecorder.failingWriteDescriptors }
        set { sourceDescriptorRecorder.failingWriteDescriptors = newValue }
    }
    var maximumWriteByteCount: Int? {
        get { sourceDescriptorRecorder.maximumWriteByteCount }
        set { sourceDescriptorRecorder.maximumWriteByteCount = newValue }
    }
    var failingCloseDescriptors: [Int32: Int32] {
        get { sourceDescriptorRecorder.failingCloseDescriptors }
        set { sourceDescriptorRecorder.failingCloseDescriptors = newValue }
    }
    var prepareSourceDescriptorForWriting: @Sendable (Int32) throws -> Void {
        get { sourceDescriptorRecorder.prepareDescriptorForWriting }
        set { sourceDescriptorRecorder.prepareDescriptorForWriting = newValue }
    }
    var descriptorWrites: [DescriptorWrite] {
        sourceDescriptorRecorder.descriptorWrites
    }
    var closedDescriptors: [Int32] {
        descriptorCloseRecorder.descriptors
    }

    private var bindings: [SeatID: RecordingDataTransferDeviceBinding] = [:]
    private var offerBindingsByHandle: [RawDataOfferHandle: RecordingDataTransferOfferBinding] = [:]
    private var sourceBindings: [DataSourceID: RecordingDataTransferSourceBinding] = [:]
    private let descriptorCloseRecorder = DescriptorCloseRecorder()
    private lazy var sourceDescriptorRecorder =
        RecordingSourceDescriptorIO(closeRecorder: descriptorCloseRecorder)

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

        let binding = RecordingDataTransferSourceBinding(
            id: sourceBindingIDOverride ?? id,
            protocolVersion: sourceBindingProtocolVersion,
            onEvent: onEvent
        )
        sourceBindings[id] = binding
        return binding
    }

    func prepareDragIcon(_ icon: DragIcon) throws -> (any DataTransferDragIconBinding)? {
        preparedDragIcons.append(icon)

        if icon == failingDragIcon {
            throw DataTransferError.cancelled
        }

        switch icon {
        case .none:
            return nil
        case .xrgb8888:
            return RecordingDataTransferDragIconBinding(icon: icon)
        }
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

    var sourceDescriptorIO: DataTransferSourceDescriptorIO {
        sourceDescriptorRecorder.descriptorIO
    }

    func writeFileDescriptor(_ descriptor: Int32, bytes: ArraySlice<UInt8>) throws -> Int {
        try sourceDescriptorRecorder.writeFileDescriptor(descriptor, bytes: bytes)
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        sourceDescriptorRecorder.closeFileDescriptor(descriptor)
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

func sourcePayloads(
    _ data: [MIMEType: Data] = [.plainText: Data("clipboard".utf8)]
) throws -> DataTransferSourcePayloadSet {
    try DataTransferSourcePayloadSet(data: data)
}

func sourcePayloads(for mimeTypes: [MIMEType]) throws -> DataTransferSourcePayloadSet {
    try DataTransferSourcePayloadSet(
        payloads: mimeTypes.map { mimeType in
            ClipboardSourcePayload(mimeType: mimeType, data: Data())
        }
    )
}

extension DataTransferManager {
    func setSelectionSource(
        seatID: SeatID,
        mimeTypes: [MIMEType],
        serial: InputSerial,
        payloads: DataTransferSourcePayloadSet? = nil
    ) throws -> DataSourceSnapshot {
        let sourcePayloads = try payloads ?? sourcePayloads(for: mimeTypes)
        precondition(
            sourcePayloads.mimeTypes == mimeTypes,
            "Test source payloads must match advertised MIME types"
        )
        return try setSelectionSource(
            seatID: seatID,
            payloads: sourcePayloads,
            serial: serial
        )
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

private final class RecordingSourceDescriptorIO: Sendable {
    private let closeRecorder: DescriptorCloseRecorder
    private let storage = Mutex(RecordingSourceDescriptorIOState())

    init(closeRecorder descriptorCloseRecorder: DescriptorCloseRecorder) {
        closeRecorder = descriptorCloseRecorder
    }

    var descriptorIO: DataTransferSourceDescriptorIO {
        DataTransferSourceDescriptorIO(
            prepareDescriptorForWriting: { descriptor in
                try self.prepareDescriptorForWriting(descriptor)
            },
            writeDescriptor: { descriptor, bytes in
                try self.writeFileDescriptor(descriptor, bytes: bytes)
            },
            closeDescriptor: { descriptor in
                self.closeFileDescriptor(descriptor)
            }
        )
    }

    var failingWriteDescriptors: [Int32: DataTransferError] {
        get { storage.withLock(\.failingWriteDescriptors) }
        set { storage.withLock { $0.failingWriteDescriptors = newValue } }
    }

    var maximumWriteByteCount: Int? {
        get { storage.withLock(\.maximumWriteByteCount) }
        set { storage.withLock { $0.maximumWriteByteCount = newValue } }
    }

    var failingCloseDescriptors: [Int32: Int32] {
        get { storage.withLock(\.failingCloseDescriptors) }
        set { storage.withLock { $0.failingCloseDescriptors = newValue } }
    }

    var prepareDescriptorForWriting: @Sendable (Int32) throws -> Void {
        get { storage.withLock(\.prepareDescriptorForWriting) }
        set { storage.withLock { $0.prepareDescriptorForWriting = newValue } }
    }

    var descriptorWrites: [RecordingDataTransferBackend.DescriptorWrite] {
        storage.withLock(\.descriptorWrites)
    }

    func prepareDescriptorForWriting(_ descriptor: Int32) throws {
        let prepare = storage.withLock(\.prepareDescriptorForWriting)
        try prepare(descriptor)
    }

    func writeFileDescriptor(_ descriptor: Int32, bytes: ArraySlice<UInt8>) throws -> Int {
        try storage.withLock { storage in
            if let error = storage.failingWriteDescriptors[descriptor] {
                throw error
            }

            let bytesToWrite: [UInt8]
            if let maximumWriteByteCount = storage.maximumWriteByteCount {
                bytesToWrite = Array(bytes.prefix(maximumWriteByteCount))
            } else {
                bytesToWrite = Array(bytes)
            }

            storage.descriptorWrites.append(
                RecordingDataTransferBackend.DescriptorWrite(
                    descriptor: descriptor,
                    bytes: bytesToWrite
                )
            )
            return bytesToWrite.count
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

private struct RecordingSourceDescriptorIOState: Sendable {
    var failingWriteDescriptors: [Int32: DataTransferError] = [:]
    var maximumWriteByteCount: Int?
    var failingCloseDescriptors: [Int32: Int32] = [:]
    var prepareDescriptorForWriting: @Sendable (Int32) throws -> Void = { _ in return }
    var descriptorWrites: [RecordingDataTransferBackend.DescriptorWrite] = []
}

final class RecordingDataTransferDeviceBinding: DataTransferDeviceBinding {
    struct Selection: Equatable {
        let sourceID: DataSourceID?
        let serial: InputSerial
    }

    struct DragStart: Equatable {
        let sourceID: DataSourceID
        let originID: UInt64
        let icon: DragIcon?
        let serial: InputSerial
    }

    let seatID: SeatID
    var protocolVersion: RawVersion
    var releaseCount = 0
    var selections: [Selection] = []
    var dragStarts: [DragStart] = []

    private let onEvent: (RawDataDeviceEvent) -> Void

    init(
        seatID bindingSeatID: SeatID,
        protocolVersion bindingProtocolVersion: RawVersion = 3,
        onEvent eventHandler: @escaping (RawDataDeviceEvent) -> Void
    ) {
        seatID = bindingSeatID
        protocolVersion = bindingProtocolVersion
        onEvent = eventHandler
    }

    func emit(_ event: RawDataDeviceEvent) {
        onEvent(event)
    }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial) {
        selections.append(Selection(sourceID: source?.id, serial: serial))
    }

    func startDrag(
        source: any DataTransferSourceBinding,
        origin: any DataTransferDragOriginBinding,
        icon: (any DataTransferDragIconBinding)?,
        serial: InputSerial
    ) {
        let recordingOrigin = origin as? RecordingDataTransferDragOriginBinding
        guard let recordingOrigin else {
            preconditionFailure("test drag origin is missing")
        }
        let recordingIcon = icon as? RecordingDataTransferDragIconBinding
        dragStarts.append(
            DragStart(
                sourceID: source.id,
                originID: recordingOrigin.id,
                icon: recordingIcon?.icon,
                serial: serial
            )
        )
    }

    func release() {
        releaseCount += 1
    }
}

final class RecordingDataTransferDragOriginBinding: DataTransferDragOriginBinding {
    let id: UInt64

    init(id originID: UInt64) {
        id = originID
    }
}

final class RecordingDataTransferDragIconBinding: DataTransferDragIconBinding {
    let icon: DragIcon
    var destroyCount = 0

    init(icon dragIcon: DragIcon) {
        icon = dragIcon
    }

    func destroy() {
        destroyCount += 1
    }
}

final class RecordingDataTransferOfferBinding: DataTransferOfferBinding {
    struct Receive: Equatable {
        let mimeType: MIMEType
        let fd: Int32
    }

    struct Accept: Equatable {
        let serial: InputSerial
        let mimeType: MIMEType?
    }

    struct ActionRequest: Equatable {
        let actions: DragActionSet
        let preferredAction: DragAction
    }

    let id: DataOfferID
    var protocolVersion: RawVersion
    var destroyCount = 0
    var receives: [Receive] = []
    var accepts: [Accept] = []
    var actionRequests: [ActionRequest] = []
    var finishCount = 0

    private let onEvent: (RawDataOfferEvent) -> Void

    init(
        id offerID: DataOfferID,
        protocolVersion bindingProtocolVersion: RawVersion = 3,
        onEvent eventHandler: @escaping (RawDataOfferEvent) -> Void
    ) {
        id = offerID
        protocolVersion = bindingProtocolVersion
        onEvent = eventHandler
    }

    func emit(_ event: RawDataOfferEvent) {
        onEvent(event)
    }

    func receive(mimeType: MIMEType, fd: Int32) {
        receives.append(Receive(mimeType: mimeType, fd: fd))
    }

    func accept(serial: InputSerial, mimeType: MIMEType?) {
        accepts.append(Accept(serial: serial, mimeType: mimeType))
    }

    func setDragActions(_ actions: DragActionSet, preferredAction: DragAction) {
        actionRequests.append(ActionRequest(actions: actions, preferredAction: preferredAction))
    }

    func finish() {
        finishCount += 1
    }

    func destroy() {
        destroyCount += 1
    }
}

final class RecordingDataTransferSourceBinding: DataTransferSourceBinding {
    let id: DataSourceID
    var protocolVersion: RawVersion
    var offeredMimeTypes: [MIMEType] = []
    var actionRequests: [DragActionSet] = []
    var dragIcon: (any DataTransferDragIconBinding)?
    var destroyCount = 0

    private let onEvent: (RawDataSourceEvent) -> Void

    init(
        id sourceID: DataSourceID,
        protocolVersion bindingProtocolVersion: RawVersion = 3,
        onEvent eventHandler: @escaping (RawDataSourceEvent) -> Void
    ) {
        id = sourceID
        protocolVersion = bindingProtocolVersion
        onEvent = eventHandler
    }

    func emit(_ event: RawDataSourceEvent) {
        onEvent(event)
    }

    func offer(mimeType: MIMEType) {
        offeredMimeTypes.append(mimeType)
    }

    func setDragActions(_ actions: DragActionSet) {
        actionRequests.append(actions)
    }

    func attachDragIcon(_ icon: (any DataTransferDragIconBinding)?) {
        dragIcon = icon
    }

    func destroy() {
        dragIcon?.destroy()
        dragIcon = nil
        destroyCount += 1
    }
}
