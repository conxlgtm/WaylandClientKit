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
