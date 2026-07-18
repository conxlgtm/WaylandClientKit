import WaylandRaw

final class ClipboardSelectionEngineBackend: SelectionEngineBackend {
    private let backend: any DataTransferManagerBackend
    private let onDragDeviceEvent: (RawDataDeviceEvent, SeatID) -> Void
    private let onDragOfferEvent: (RawDataOfferEvent, DataOfferID) -> Void

    init(
        backend dataTransferBackend: any DataTransferManagerBackend,
        onDragDeviceEvent dragDeviceEventHandler:
            @escaping (RawDataDeviceEvent, SeatID) -> Void,
        onDragOfferEvent dragOfferEventHandler:
            @escaping (RawDataOfferEvent, DataOfferID) -> Void
    ) {
        backend = dataTransferBackend
        onDragDeviceEvent = dragDeviceEventHandler
        onDragOfferEvent = dragOfferEventHandler
    }

    func preconditionIsOwnerThread() {
        backend.preconditionIsOwnerThread()
    }

    func bindDevice(
        for seatID: SeatID,
        onEvent: @escaping (SelectionEngineDeviceEvent) -> Void
    ) throws -> any SelectionEngineDeviceBinding {
        let binding = try backend.bindDataDevice(for: seatID) { [onDragDeviceEvent] event in
            switch event {
            case .dataOffer(let handle):
                onEvent(.dataOffer(handle.map(SelectionEngineOfferHandle.clipboard)))
            case .selection(let handle):
                onEvent(.selection(handle.map(SelectionEngineOfferHandle.clipboard)))
            case .enter, .leave, .drop, .motion:
                onDragDeviceEvent(event, seatID)
            }
        }
        return ClipboardSelectionDeviceBinding(binding)
    }

    func adoptOffer(
        handle: SelectionEngineOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (SelectionEngineOfferEvent) -> Void
    ) throws -> any DataTransferOfferResourceBinding {
        guard case .clipboard(let rawHandle) = handle else {
            preconditionFailure("clipboard selection received a primary-selection offer handle")
        }

        return try backend.adoptDataOffer(handle: rawHandle, id: id) { [onDragOfferEvent] event in
            switch event {
            case .offer(let rawMIMEType):
                onEvent(.mimeType(rawMIMEType))
            case .sourceActions, .action:
                onDragOfferEvent(event, id)
            }
        }
    }

    func createSource(
        id: DataSourceID,
        onEvent: @escaping (SelectionEngineSourceEvent) -> Void
    ) throws -> any DataTransferSourceResourceBinding {
        try backend.createDataSource(id: id) { event in
            switch event {
            case .send(let rawMIMEType, let descriptor):
                onEvent(.send(mimeType: rawMIMEType, descriptor: descriptor))
            case .cancelled:
                onEvent(.cancelled)
            case .target:
                onEvent(.target)
            case .dndDropPerformed:
                onEvent(.invalidDragAndDropEvent(.dndDropPerformed))
            case .dndFinished:
                onEvent(.invalidDragAndDropEvent(.dndFinished))
            case .action:
                onEvent(.invalidDragAndDropEvent(.action))
            }
        }
    }

    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors {
        try backend.makeOfferReceivePipe()
    }

    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor {
        try backend.adoptOwnedFileDescriptor(descriptor)
    }

    var sourceDescriptorIO: DataTransferSourceDescriptorIO {
        backend.sourceDescriptorIO
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        backend.closeFileDescriptor(descriptor)
    }
}

private final class ClipboardSelectionDeviceBinding: SelectionEngineDeviceBinding {
    private let binding: any DataTransferDeviceBinding

    init(_ dataDeviceBinding: any DataTransferDeviceBinding) {
        binding = dataDeviceBinding
    }

    var dragAndDropBinding: (any DataTransferDeviceBinding)? {
        binding
    }

    func setSelection(
        source: (any DataTransferSourceResourceBinding)?,
        serial: InputSerial
    ) {
        guard let source else {
            binding.setSelection(source: nil, serial: serial)
            return
        }
        guard let dataSource = source as? any DataTransferSourceBinding else {
            preconditionFailure("clipboard source is not backed by a data-device source")
        }
        binding.setSelection(source: dataSource, serial: serial)
    }

    func release() {
        binding.release()
    }
}
