import Testing

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceLifecycleTests {
    @Test
    func seatRemovalPublishesSourceCancellationForOwnedSelection() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 71)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        _ = manager.drainDataTransferEvents()

        try manager.synchronizeSeats([])

        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(
            manager.drainDataTransferEvents()
                == [.clipboardSourceCancelled(ClipboardSourceIdentity(source.id))]
        )
    }
}
