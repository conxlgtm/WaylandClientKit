import Glibc
import WaylandRaw

final class LivePrimarySelectionControllerBackend: PrimarySelectionControllerBackend {
    private let connection: RawDisplayConnection

    init(connection rawConnection: RawDisplayConnection) {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    func bindPrimarySelectionDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawPrimarySelectionDeviceEvent) -> Void
    ) throws -> any PrimarySelectionDeviceBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.primarySelectionDeviceManager else {
            throw DataTransferError.unavailable
        }
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw DataTransferError.unknownSeat(seatID)
        }

        let device = try manager.getDevice(for: seat)
        let owner = RawPrimarySelectionDeviceOwner(
            onEvent: onEvent,
            invariantFailureSink: connection.invariantFailureSink
        )
        do {
            try owner.install(on: device)
        } catch {
            owner.cancel()
            device.destroy()
            throw error
        }

        return LivePrimarySelectionDeviceBinding(
            device: device,
            owner: owner
        )
    }

    func adoptPrimarySelectionOffer(
        handle: RawPrimarySelectionOfferHandle,
        id _: DataOfferID,
        onEvent: @escaping (RawPrimarySelectionOfferEvent) -> Void
    ) throws -> any DataTransferOfferResourceBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.primarySelectionDeviceManager else {
            throw DataTransferError.unavailable
        }

        let offer = try manager.adoptOffer(handle)
        let owner = RawPrimarySelectionOfferOwner(
            onEvent: onEvent,
            invariantFailureSink: connection.invariantFailureSink
        )
        do {
            try owner.install(on: offer)
        } catch {
            owner.cancel()
            offer.destroy()
            throw error
        }

        return LivePrimarySelectionOfferBinding(offer: offer, owner: owner)
    }

    func createPrimarySelectionSource(
        id: DataSourceID,
        onEvent: @escaping (RawPrimarySelectionSourceEvent) -> Void
    ) throws -> any DataTransferSourceResourceBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.primarySelectionDeviceManager else {
            throw DataTransferError.unavailable
        }

        let source = try manager.createSource()
        let owner = RawPrimarySelectionSourceOwner(
            onEvent: onEvent,
            invariantFailureSink: connection.invariantFailureSink
        )
        do {
            try owner.install(on: source)
        } catch {
            owner.cancel()
            source.destroy()
            throw error
        }

        return LivePrimarySelectionSourceBinding(id: id, source: source, owner: owner)
    }

    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors {
        try DataTransferPipeDescriptors.makeOfferReceivePipe()
    }

    func adoptOwnedFileDescriptor(_ descriptor: Int32) throws -> OwnedFileDescriptor {
        try OwnedFileDescriptor(adopting: descriptor)
    }

    var sourceDescriptorIO: DataTransferSourceDescriptorIO {
        .raw
    }

    func closeFileDescriptor(_ descriptor: Int32) -> FileDescriptorCloseResult {
        FileDescriptorCloseResult.posixReturn(Glibc.close(descriptor))
    }
}

private final class LivePrimarySelectionDeviceBinding: PrimarySelectionDeviceBinding {
    private let device: RawPrimarySelectionDevice
    private let owner: RawPrimarySelectionDeviceOwner
    private var isReleased = false

    init(
        device rawDevice: RawPrimarySelectionDevice,
        owner listenerOwner: RawPrimarySelectionDeviceOwner
    ) {
        device = rawDevice
        owner = listenerOwner
    }

    func setSelection(
        source: (any DataTransferSourceResourceBinding)?,
        serial: InputSerial
    ) {
        precondition(!isReleased, "primary selection device binding was already released")
        let liveSource = source as? LivePrimarySelectionSourceBinding
        device.setSelection(source: liveSource?.source, serial: serial.rawValue)
    }

    func release() {
        guard !isReleased else {
            return
        }

        isReleased = true
        owner.cancel()
        device.destroy()
    }

    deinit {
        release()
    }
}

private final class LivePrimarySelectionOfferBinding: DataTransferOfferResourceBinding {
    private let offer: RawPrimarySelectionOffer
    private let owner: RawPrimarySelectionOfferOwner
    private var isDestroyed = false

    init(
        offer rawOffer: RawPrimarySelectionOffer,
        owner listenerOwner: RawPrimarySelectionOfferOwner
    ) {
        offer = rawOffer
        owner = listenerOwner
    }

    func receive(mimeType: MIMEType, fd: Int32) {
        precondition(!isDestroyed, "primary selection offer binding was already destroyed")
        offer.receive(mimeType: mimeType.rawValue, fd: fd)
    }

    func destroy() {
        guard !isDestroyed else {
            return
        }

        isDestroyed = true
        owner.cancel()
        offer.destroy()
    }

    deinit {
        destroy()
    }
}

private final class LivePrimarySelectionSourceBinding: DataTransferSourceResourceBinding {
    let id: DataSourceID

    let source: RawPrimarySelectionSource
    private let owner: RawPrimarySelectionSourceOwner
    private var isDestroyed = false

    init(
        id sourceID: DataSourceID,
        source rawSource: RawPrimarySelectionSource,
        owner listenerOwner: RawPrimarySelectionSourceOwner
    ) {
        id = sourceID
        source = rawSource
        owner = listenerOwner
    }

    func offer(mimeType: MIMEType) {
        precondition(!isDestroyed, "primary selection source binding was already destroyed")
        source.offer(mimeType: mimeType.rawValue)
    }

    func destroy() {
        guard !isDestroyed else {
            return
        }

        isDestroyed = true
        owner.cancel()
        source.destroy()
    }

    deinit {
        destroy()
    }
}
