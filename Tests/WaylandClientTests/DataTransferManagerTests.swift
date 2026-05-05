import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerTests {
    private let seat1 = SeatID(rawValue: 1)
    private let seat2 = SeatID(rawValue: 2)

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

private final class RecordingDataTransferBackend: DataTransferManagerBackend {
    var boundSeatIDs: [SeatID] = []
    var failingSeatID: SeatID?

    private var bindings: [SeatID: RecordingDataTransferDeviceBinding] = [:]

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

    func binding(for seatID: SeatID) -> RecordingDataTransferDeviceBinding? {
        bindings[seatID]
    }
}

private final class RecordingDataTransferDeviceBinding: DataTransferDeviceBinding {
    let seatID: SeatID
    var releaseCount = 0

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

    func release() {
        releaseCount += 1
    }
}
