import Testing

@testable import WaylandClient

@Suite
struct DataTransferSourceCancelHookTests {
    private let seatID = SeatID(rawValue: 1)
    private let origin = RecordingDataTransferDragOriginBinding(id: 0x58)
    private let serial = InputSerial(rawValue: 45)

    @Test
    func manualDragCancellationCallsHookBeforeDestroyingSource() throws {
        var cancelledSourceIDs: [DataSourceID] = []
        var binding: RecordingDataTransferSourceBinding?
        let sourceWillCancel: (DataSourceID) -> Void = { sourceID in
            cancelledSourceIDs.append(sourceID)
            #expect(binding?.destroyCount == 0)
        }
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(
            backend: backend,
            sourceWillCancel: sourceWillCancel
        )
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(try startDragRequest())
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        binding = sourceBinding

        try manager.cancelDragSource(id: source.id)

        #expect(cancelledSourceIDs == [source.id])
        #expect(sourceBinding.destroyCount == 1)
    }

    @Test
    func compositorDragCancellationCallsHookBeforeDestroyingSource() throws {
        var cancelledSourceIDs: [DataSourceID] = []
        var binding: RecordingDataTransferSourceBinding?
        let sourceWillCancel: (DataSourceID) -> Void = { sourceID in
            cancelledSourceIDs.append(sourceID)
            #expect(binding?.destroyCount == 0)
        }
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(
            backend: backend,
            sourceWillCancel: sourceWillCancel
        )
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(try startDragRequest())
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        binding = sourceBinding

        sourceBinding.emit(.cancelled)

        #expect(cancelledSourceIDs == [source.id])
        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.drainDataTransferEvents() == [.dragSourceCancelled(.init(source.id))])
    }

    @Test
    func cancellationHookReentrySeesCommittedStateBeforeDestruction() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let source = try manager.startDrag(try startDragRequest())
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        var reentryError: DataTransferError?
        var invariantError: (any Error)?
        var eventsDuringHook: [DataTransferEvent] = []
        manager.sourceWillCancel = { [weak manager] sourceID in
            #expect(sourceBinding.destroyCount == 0)
            #expect(manager?.sourceSnapshots.contains { $0.id == sourceID } == false)
            eventsDuringHook = manager?.drainDataTransferEvents() ?? []
            do {
                try manager?.checkInvariantsForTesting()
                try manager?.cancelDragSource(id: sourceID)
            } catch let error as DataTransferError {
                reentryError = error
            } catch {
                invariantError = error
            }
        }

        try manager.cancelDragSource(id: source.id)

        #expect(invariantError == nil)
        #expect(reentryError == .unknownDragSourceIdentity(source.id.dragIdentity))
        #expect(eventsDuringHook.isEmpty)
        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.drainDataTransferEvents() == [.dragSourceCancelled(source.id.dragIdentity)])
    }

    private func startDragRequest() throws -> DataTransferStartDragRequest {
        try DataTransferStartDragRequest(
            seatID: seatID,
            payloads: sourcePayloads(for: [.plainText]),
            actions: [.copy],
            serial: serial,
            origin: origin,
            icon: .none
        )
    }
}
