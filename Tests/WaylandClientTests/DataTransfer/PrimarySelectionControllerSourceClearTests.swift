import Foundation
import Testing

@testable import WaylandClient

@Suite
struct PrimarySelectionControllerSourceClearTests {
    private let seat = SeatID(rawValue: 1)
    private let firstSerial = InputSerial(rawValue: 55)
    private let secondSerial = InputSerial(rawValue: 56)
    private let staleClearSerial = InputSerial(rawValue: 57)
    private let currentClearSerial = InputSerial(rawValue: 58)

    @Test
    func clearingStalePrimarySelectionSourceIDDoesNotClearCurrentSource() throws {
        let backend = RecordingPrimarySelectionBackend()
        let controller = PrimarySelectionController(backend: backend)
        let payloads = try primarySelectionPayloads([.plainText: Data("primary".utf8)])

        try controller.synchronizeSeats([seat])
        let firstSource = try controller.setSelectionSource(
            seatID: seat,
            payloads: payloads,
            serial: firstSerial
        )
        let secondSource = try controller.setSelectionSource(
            seatID: seat,
            payloads: payloads,
            serial: secondSerial
        )
        let firstBinding = try #require(backend.sourceBinding(for: firstSource.id))
        let secondBinding = try #require(backend.sourceBinding(for: secondSource.id))
        let device = try #require(backend.binding(for: seat))
        _ = controller.drainDataTransferEvents()

        #expect(throws: DataTransferError.sourceCancelled) {
            try controller.clearSelectionSource(
                id: firstSource.id,
                seatID: seat,
                serial: staleClearSerial
            )
        }

        #expect(firstBinding.destroyCount == 1)
        #expect(secondBinding.destroyCount == 0)
        #expect(
            device.selections == [
                .init(sourceID: firstSource.id, serial: firstSerial),
                .init(sourceID: secondSource.id, serial: secondSerial),
            ]
        )
        #expect(controller.drainDataTransferEvents().isEmpty)

        try controller.clearSelectionSource(
            id: secondSource.id,
            seatID: seat,
            serial: currentClearSerial
        )

        #expect(secondBinding.destroyCount == 1)
        #expect(
            device.selections == [
                .init(sourceID: firstSource.id, serial: firstSerial),
                .init(sourceID: secondSource.id, serial: secondSerial),
                .init(sourceID: nil, serial: currentClearSerial),
            ]
        )
        #expect(
            controller.drainDataTransferEvents()
                == [
                    .primarySelectionSourceCancelled(
                        PrimarySelectionSourceIdentity(secondSource.id)
                    )
                ]
        )
    }
}
