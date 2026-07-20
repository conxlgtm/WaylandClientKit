import WaylandRaw

final class PrimarySelectionEngineBackend: SelectionEngineBackend {
    private let backend: any PrimarySelectionControllerBackend

    init(backend primarySelectionBackend: any PrimarySelectionControllerBackend) {
        backend = primarySelectionBackend
    }

    func preconditionIsOwnerThread() {
        backend.preconditionIsOwnerThread()
    }

    func bindDevice(
        for seatID: SeatID,
        onEvent: @escaping (SelectionEngineDeviceEvent) -> Void
    ) throws -> any SelectionEngineDeviceBinding {
        let binding = try backend.bindPrimarySelectionDevice(for: seatID) { event in
            switch event {
            case .dataOffer(let handle):
                onEvent(.dataOffer(handle.map(SelectionEngineOfferHandle.primarySelection)))
            case .selection(let handle):
                onEvent(.selection(handle.map(SelectionEngineOfferHandle.primarySelection)))
            }
        }
        return PrimarySelectionEngineDeviceBinding(binding)
    }

    func adoptOffer(
        handle: SelectionEngineOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (SelectionEngineOfferEvent) -> Void
    ) throws -> any DataTransferOfferResourceBinding {
        guard case .primarySelection(let rawHandle) = handle else {
            preconditionFailure("primary selection received a clipboard offer handle")
        }

        return try backend.adoptPrimarySelectionOffer(
            handle: rawHandle,
            id: id
        ) { event in
            switch event {
            case .offer(let rawMIMEType):
                onEvent(.mimeType(rawMIMEType))
            }
        }
    }

    func createSource(
        id: DataSourceID,
        onEvent: @escaping (SelectionEngineSourceEvent) -> Void
    ) throws -> any DataTransferSourceResourceBinding {
        try backend.createPrimarySelectionSource(id: id) { event in
            switch event {
            case .send(let rawMIMEType, let descriptor):
                onEvent(.send(mimeType: rawMIMEType, descriptor: descriptor))
            case .cancelled:
                onEvent(.cancelled)
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

private final class PrimarySelectionEngineDeviceBinding: SelectionEngineDeviceBinding {
    private let binding: any PrimarySelectionDeviceBinding

    init(_ primarySelectionBinding: any PrimarySelectionDeviceBinding) {
        binding = primarySelectionBinding
    }

    var dragAndDropBinding: (any DataTransferDeviceBinding)? {
        nil
    }

    func setSelection(
        source: (any DataTransferSourceResourceBinding)?,
        serial: InputSerial
    ) {
        binding.setSelection(source: source, serial: serial)
    }

    func release() {
        binding.release()
    }
}
