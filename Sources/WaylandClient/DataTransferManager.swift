import WaylandRaw

package struct DataTransferSelectionChange: Equatable, Sendable {
    package let seatID: SeatID
    package let offerID: DataOfferID?
}

package protocol DataTransferDeviceBinding: AnyObject {
    var seatID: SeatID { get }

    func release()
}

package protocol DataTransferManagerBackend: AnyObject {
    func preconditionIsOwnerThread()
    func bindDataDevice(
        for seatID: SeatID,
        onEvent: @escaping (RawDataDeviceEvent) -> Void
    ) throws -> any DataTransferDeviceBinding
}

package final class DataTransferManager {
    private let backend: any DataTransferManagerBackend
    private var state = DataTransferState()
    private var deviceBindings: [SeatID: any DataTransferDeviceBinding] = [:]
    private var pendingCallbackError: (any Error)?

    package private(set) var selectionChanges: [DataTransferSelectionChange] = []
    package private(set) var sourceCancellations: [DataSourceID] = []

    package init(connection rawConnection: RawDisplayConnection) {
        backend = LiveDataTransferManagerBackend(connection: rawConnection)
    }

    package init(backend dataTransferBackend: any DataTransferManagerBackend) {
        dataTransferBackend.preconditionIsOwnerThread()
        backend = dataTransferBackend
    }

    package var seatSnapshots: [DataTransferSeatSnapshot] {
        state.seatSnapshots
    }

    package var offerSnapshots: [DataOfferSnapshot] {
        state.offerSnapshots
    }

    package var sourceSnapshots: [DataSourceSnapshot] {
        state.sourceSnapshots
    }

    package func synchronizeSeats(_ seatIDs: [SeatID]) throws {
        backend.preconditionIsOwnerThread()
        try throwPendingCallbackErrorIfAny()

        let desiredSeats = Set(seatIDs)
        let currentSeats = Set(state.seatSnapshots.map(\.seatID))
        for seatID in Self.sortedSeatIDs(currentSeats.subtracting(desiredSeats)) {
            try apply(.seatRemoved(seatID))
        }
        for seatID in Self.sortedSeatIDs(desiredSeats.subtracting(currentSeats)) {
            try apply(.seatAvailable(seatID))
        }
    }

    package func throwPendingCallbackErrorIfAny() throws {
        backend.preconditionIsOwnerThread()
        guard let error = pendingCallbackError else {
            return
        }

        pendingCallbackError = nil
        throw error
    }

    private func apply(_ action: DataTransferAction) throws {
        var nextState = state
        let plan = try nextState.reduce(action)
        nextState = plan.state

        do {
            try interpret(plan.effects, nextState: &nextState)
        } catch {
            rollbackBindings(for: state)
            throw error
        }

        state = nextState
    }

    private func interpret(
        _ effects: [DataTransferEffect],
        nextState: inout DataTransferState
    ) throws {
        for effect in effects {
            try interpret(effect, nextState: &nextState)
        }
    }

    private func interpret(
        _ effect: DataTransferEffect,
        nextState: inout DataTransferState
    ) throws {
        switch effect {
        case .bindDataDevice(let seatID):
            try bindDataDevice(for: seatID, nextState: &nextState)
        case .releaseDataDevice(let seatID):
            deviceBindings.removeValue(forKey: seatID)?.release()
        case .destroyOffer:
            break
        case .cancelSource:
            break
        case .publishSelectionChanged(let seatID, let offerID):
            selectionChanges.append(
                DataTransferSelectionChange(seatID: seatID, offerID: offerID)
            )
        case .publishSourceCancelled(let sourceID):
            sourceCancellations.append(sourceID)
        }
    }

    private func bindDataDevice(
        for seatID: SeatID,
        nextState: inout DataTransferState
    ) throws {
        guard deviceBindings[seatID] == nil else {
            return
        }

        let binding = try backend.bindDataDevice(for: seatID) { [weak self] event in
            self?.handleDataDeviceEvent(event, seatID: seatID)
        }
        do {
            nextState = try nextState.reduce(.dataDeviceBound(seatID)).state
        } catch {
            binding.release()
            throw error
        }

        deviceBindings[seatID] = binding
    }

    private func handleDataDeviceEvent(_ event: RawDataDeviceEvent, seatID: SeatID) {
        do {
            switch event {
            case .selection(nil):
                try apply(.selectionChanged(seatID: seatID, offerID: nil))
            default:
                break
            }
        } catch {
            pendingCallbackError = error
        }
    }

    private func rollbackBindings(for committedState: DataTransferState) {
        let liveSeats = Set(committedState.seatSnapshots.map(\.seatID))
        for seatID in deviceBindings.keys where !liveSeats.contains(seatID) {
            deviceBindings.removeValue(forKey: seatID)?.release()
        }
    }

    private static func sortedSeatIDs(_ seatIDs: Set<SeatID>) -> [SeatID] {
        seatIDs.sorted { $0.rawValue < $1.rawValue }
    }
}

private final class LiveDataTransferManagerBackend: DataTransferManagerBackend {
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
}

private final class LiveDataTransferDeviceBinding: DataTransferDeviceBinding {
    let seatID: SeatID

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
