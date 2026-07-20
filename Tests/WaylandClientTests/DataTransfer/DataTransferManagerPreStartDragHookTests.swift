import Foundation
import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct DataTransferManagerPreStartDragHookTests {
    private let seatID = SeatID(rawValue: 1)
    private let origin = RecordingDataTransferDragOriginBinding(id: 0x57)
    private let serial = InputSerial(rawValue: 44)

    @Test
    func startDragRunsPreStartHookBeforeStartDragRequest() throws {
        let backend = RecordingDataTransferBackend()
        var order: [String] = []
        backend.onStartDrag = { order.append("start_drag") }
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        _ = try manager.startDrag(
            try startDragRequest { source in
                order.append("before")
                #expect(source.id == DataSourceID(rawValue: 1))
            }
        )

        #expect(order == ["before", "start_drag"])
    }

    @Test
    func failedPreStartPreparationLeavesNoSourceState() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        #expect(throws: StartDragPreparationError.stopped) {
            _ = try manager.startDrag(
                try startDragRequest { _ in
                    throw StartDragPreparationError.stopped
                }
            )
        }

        let sourceID = DataSourceID(rawValue: 1)
        #expect(backend.sourceBinding(for: sourceID)?.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(backend.binding(for: seatID)?.dragStarts.isEmpty == true)
        #expect(manager.drainDataTransferEvents().isEmpty)
        try manager.checkInvariantsForTesting()
    }

    private func startDragRequest(
        beforeStartDrag: @escaping (any DataTransferSourceBinding) throws -> Void
    ) throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: dragPayloads(),
            actions: [.copy],
            serial: serial,
            origin: origin,
            icon: .none,
            beforeStartDrag: beforeStartDrag
        )
    }

    private func dragPayloads() throws -> DataTransferSourcePayloadSet {
        try DataTransferSourcePayloadSet(
            data: [.plainText: Data("drag source".utf8)]
        )
    }
}

private enum StartDragPreparationError: Error, Equatable {
    case stopped
}
