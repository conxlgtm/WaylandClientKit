import WaylandRaw

package final class PrimarySelectionController {
    package let backend: any PrimarySelectionControllerBackend
    let eventQueue: DataTransferEventQueue
    let selectionEngine: SelectionEngine

    package init(
        connection rawConnection: RawDisplayConnection,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue()
    ) {
        let liveBackend = LivePrimarySelectionControllerBackend(connection: rawConnection)
        backend = liveBackend
        eventQueue = dataTransferEventQueue
        selectionEngine = SelectionEngine(
            kind: .primarySelection,
            backend: PrimarySelectionEngineBackend(backend: liveBackend),
            eventQueue: dataTransferEventQueue
        )
    }

    package init(
        backend controllerBackend: any PrimarySelectionControllerBackend,
        eventQueue dataTransferEventQueue: DataTransferEventQueue = DataTransferEventQueue()
    ) {
        controllerBackend.preconditionIsOwnerThread()
        backend = controllerBackend
        eventQueue = dataTransferEventQueue
        selectionEngine = SelectionEngine(
            kind: .primarySelection,
            backend: PrimarySelectionEngineBackend(backend: controllerBackend),
            eventQueue: dataTransferEventQueue
        )
    }

    package func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        try selectionEngine.synchronizeSeats(seatIDs)
    }

    package func offer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        try selectionEngine.offer(for: seatID)
    }

    package func receiveOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try selectionEngine.receiveOffer(id: offerID, mimeType: mimeType)
    }

    package func setSelectionSource(
        seatID: SeatID,
        payloads: DataTransferSourcePayloadSet,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        try selectionEngine.setSelectionSource(
            seatID: seatID,
            payloads: payloads,
            serial: serial
        )
    }

    package func clearSelectionSource(
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try selectionEngine.clearSelectionSource(seatID: seatID, serial: serial)
    }

    package func clearSelectionSource(
        id sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try selectionEngine.clearSelectionSource(
            id: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func drainDataTransferEvents() -> [DataTransferEvent] {
        backend.preconditionIsOwnerThread()
        return eventQueue.drain()
    }

    package func throwPendingCallbackErrorIfAny() throws {
        try selectionEngine.throwPendingCallbackErrorIfAny()
    }

    func recordCallbackError(
        _ error: any Error,
        context: DataTransferCallbackContext
    ) {
        selectionEngine.recordCallbackError(error, context: context)
    }

    func shutdown() {
        selectionEngine.shutdown()
    }
}
