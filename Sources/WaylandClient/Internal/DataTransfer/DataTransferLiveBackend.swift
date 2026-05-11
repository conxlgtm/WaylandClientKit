import Glibc
import WaylandRaw

final class LiveDataTransferManagerBackend: DataTransferManagerBackend {
    private let connection: RawDisplayConnection

    init(connection rawConnection: RawDisplayConnection) {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
    }

    func preconditionIsOwnerThread() {
        connection.preconditionIsOwnerThread()
    }

    func bindDataDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawDataDeviceEvent) -> Void
    ) throws -> any DataTransferDeviceBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.dataDeviceManager else {
            throw DataTransferError.unavailable
        }
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(rawValue: seatID.rawValue)) else {
            throw DataTransferError.unknownSeat(seatID)
        }

        let device = try manager.getDataDevice(for: seat)
        let owner = RawDataDeviceOwner(
            onEvent: onEvent,
            invariantFailureSink: connection.invariantFailureSink
        )
        do {
            try owner.install(on: device)
        } catch {
            owner.cancel()
            device.release()
            throw error
        }

        return LiveDataTransferDeviceBinding(
            seatID: seatID,
            device: device,
            owner: owner
        )
    }

    func adoptDataOffer(
        handle: RawDataOfferHandle,
        id: DataOfferID,
        onEvent: @escaping (RawDataOfferEvent) -> Void
    ) throws -> any DataTransferOfferBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.dataDeviceManager else {
            throw DataTransferError.unavailable
        }

        let offer = try manager.adoptDataOffer(handle)
        let owner = RawDataOfferOwner(
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

        return LiveDataTransferOfferBinding(id: id, offer: offer, owner: owner)
    }

    func createDataSource(
        id: DataSourceID,
        onEvent: @escaping (RawDataSourceEvent) -> Void
    ) throws -> any DataTransferSourceBinding {
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.dataDeviceManager else {
            throw DataTransferError.unavailable
        }

        let source = try manager.createDataSource()
        let owner = RawDataSourceOwner(
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

        return LiveDataTransferSourceBinding(id: id, source: source, owner: owner)
    }

    func makeOfferReceivePipe() throws -> DataTransferPipeDescriptors {
        do {
            let descriptors = try RawFileDescriptor.pipeDescriptors()
            return DataTransferPipeDescriptors(
                readEnd: descriptors.readEnd,
                writeEnd: descriptors.writeEnd
            )
        } catch {
            throw Self.dataTransferPipeError(error)
        }
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

    private static func dataTransferPipeError(_ error: RuntimeError) -> DataTransferError {
        switch error {
        case .system(let systemError):
            .createPipe(WaylandSystemErrno(unchecked: systemError.errno.rawValue))
        case .systemErrnoUnavailable:
            .createPipe(WaylandSystemErrno(unchecked: EIO))
        default:
            .unavailable
        }
    }
}

private final class LiveDataTransferDeviceBinding: DataTransferDeviceBinding {
    let seatID: SeatID
    var protocolVersion: RawVersion { device.version }

    private let device: RawDataDevice
    private let owner: RawDataDeviceOwner
    private var isReleased = false

    init(
        seatID bindingSeatID: SeatID,
        device rawDevice: RawDataDevice,
        owner listenerOwner: RawDataDeviceOwner
    ) {
        seatID = bindingSeatID
        device = rawDevice
        owner = listenerOwner
    }

    func setSelection(source: (any DataTransferSourceBinding)?, serial: InputSerial) {
        precondition(!isReleased, "data transfer device binding was already released")
        let liveSource = source as? LiveDataTransferSourceBinding
        device.setSelection(source: liveSource?.source, serial: serial.rawValue)
    }

    func startDrag(
        source: any DataTransferSourceBinding,
        origin: any DataTransferDragOriginBinding,
        icon: DragIcon,
        serial: InputSerial
    ) {
        precondition(!isReleased, "data transfer device binding was already released")
        guard let liveSource = source as? LiveDataTransferSourceBinding else {
            preconditionFailure("drag source binding is not backed by Wayland raw state")
        }
        guard let liveOrigin = origin as? LiveDataTransferDragOriginBinding else {
            preconditionFailure("drag origin binding is not backed by Wayland raw state")
        }
        switch icon {
        case .none:
            device.startDrag(
                source: liveSource.source,
                origin: liveOrigin.surface,
                icon: nil,
                serial: serial.rawValue
            )
        }
    }

    func release() {
        guard !isReleased else {
            return
        }

        isReleased = true
        owner.cancel()
        device.release()
    }

    deinit {
        release()
    }
}

package final class LiveDataTransferDragOriginBinding: DataTransferDragOriginBinding {
    let surface: RawSurface

    package init(surface originSurface: RawSurface) {
        surface = originSurface
    }
}

private final class LiveDataTransferOfferBinding: DataTransferOfferBinding {
    let id: DataOfferID
    var protocolVersion: RawVersion { offer.version }

    private let offer: RawDataOffer
    private let owner: RawDataOfferOwner
    private var isDestroyed = false

    init(
        id offerID: DataOfferID,
        offer rawOffer: RawDataOffer,
        owner listenerOwner: RawDataOfferOwner
    ) {
        id = offerID
        offer = rawOffer
        owner = listenerOwner
    }

    func receive(mimeType: MIMEType, fd: Int32) {
        precondition(!isDestroyed, "data transfer offer binding was already destroyed")
        offer.receive(mimeType: mimeType.rawValue, fd: fd)
    }

    func accept(serial: InputSerial, mimeType: MIMEType?) {
        precondition(!isDestroyed, "data transfer offer binding was already destroyed")
        offer.accept(serial: serial.rawValue, mimeType: mimeType?.rawValue)
    }

    func setDragActions(_ actions: DragActionSet, preferredAction: DragAction) {
        precondition(!isDestroyed, "data transfer offer binding was already destroyed")
        offer.setActions(
            actions.rawDataDeviceDNDAction,
            preferredAction: preferredAction.rawDataDeviceDNDAction
        )
    }

    func finish() {
        precondition(!isDestroyed, "data transfer offer binding was already destroyed")
        offer.finish()
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

private final class LiveDataTransferSourceBinding: DataTransferSourceBinding {
    let id: DataSourceID
    var protocolVersion: RawVersion { source.version }

    let source: RawDataSource
    private let owner: RawDataSourceOwner
    private var isDestroyed = false

    init(
        id sourceID: DataSourceID,
        source rawSource: RawDataSource,
        owner listenerOwner: RawDataSourceOwner
    ) {
        id = sourceID
        source = rawSource
        owner = listenerOwner
    }

    func offer(mimeType: MIMEType) {
        precondition(!isDestroyed, "data transfer source binding was already destroyed")
        source.offer(mimeType: mimeType.rawValue)
    }

    func setDragActions(_ actions: DragActionSet) {
        precondition(!isDestroyed, "data transfer source binding was already destroyed")
        source.setActions(actions.rawDataDeviceDNDAction)
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
