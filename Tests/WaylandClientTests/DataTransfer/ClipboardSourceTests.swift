import Foundation
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct ClipboardSourceTests {
    private let offerHandle1 = RawDataOfferHandle(uncheckedRawValue: 0xDA7A_5001)

    @Test
    func settingSelectionSourceFromClipboardConfigurationUsesOrderedPayloads() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let configuration = try ClipboardSourceConfiguration(
            payloads: [
                ClipboardSourcePayload(
                    mimeType: .plainTextUTF8,
                    data: Data("hello".utf8)
                ),
                ClipboardSourcePayload(
                    mimeType: .uriList,
                    data: Data("file:///tmp/example\n".utf8)
                ),
            ]
        )

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: configuration.mimeTypes,
            serial: InputSerial(rawValue: 45),
            payloads: configuration.payloadSet
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        #expect(sourceBinding.offeredMimeTypes == [.plainTextUTF8, .uriList])

        sourceBinding.emit(
            RawDataSourceEvent.send(mimeType: MIMEType.uriList.rawValue, fd: 190)
        )
        let requests = manager.drainSourceSendRequests()

        #expect(requests.map(\.mimeType) == [MIMEType.uriList])
        #expect(requests.map(\.data) == [Data("file:///tmp/example\n".utf8)])
        try requests.first?.close()
    }

    @Test
    func clearingSelectionSourceByIDOnlyClearsCurrentSource() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 51)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        try manager.clearSelectionSource(
            id: source.id,
            seatID: seatID,
            serial: InputSerial(rawValue: 52)
        )

        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.seatSnapshots.first?.selectionSourceID == nil)
        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: source.id,
                        serial: InputSerial(rawValue: 51)
                    ),
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: nil,
                        serial: InputSerial(rawValue: 52)
                    ),
                ]
        )
    }

    @Test
    func staleClipboardSourceHandleCannotClearReplacementSource() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))

        let first = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 61)
        )
        let second = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.uriList],
            serial: InputSerial(rawValue: 62)
        )

        #expect(throws: DataTransferError.sourceCancelled) {
            try manager.clearSelectionSource(
                id: first.id,
                seatID: seatID,
                serial: InputSerial(rawValue: 63)
            )
        }

        #expect(manager.seatSnapshots.first?.selectionSourceID == second.id)
        #expect(manager.sourceSnapshots.map(\.id) == [second.id])
        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: first.id,
                        serial: InputSerial(rawValue: 61)
                    ),
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: second.id,
                        serial: InputSerial(rawValue: 62)
                    ),
                ]
        )
    }

    @Test
    func staleClipboardSourceHandleCannotClearRemoteReplacement() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 71)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        device.emit(.dataOffer(offerHandle1))
        let offerBinding = try #require(backend.offerBinding(for: offerHandle1))
        offerBinding.emit(.offer(MIMEType.plainTextUTF8.rawValue))
        device.emit(.selection(offerHandle1))

        #expect(sourceBinding.destroyCount == 1)
        #expect(manager.seatSnapshots.first?.selectionOfferID == offerBinding.id)
        #expect(manager.seatSnapshots.first?.selectionSourceID == nil)

        #expect(throws: DataTransferError.sourceCancelled) {
            try manager.clearSelectionSource(
                id: source.id,
                seatID: seatID,
                serial: InputSerial(rawValue: 72)
            )
        }

        #expect(
            device.selections
                == [
                    RecordingDataTransferDeviceBinding.Selection(
                        sourceID: source.id,
                        serial: InputSerial(rawValue: 71)
                    )
                ]
        )
        #expect(try manager.selectionOffer(for: seatID)?.id == offerBinding.id)
    }

    @Test
    func sourceCancelledAfterRemoteReplacementDoesNotDisturbOffer() throws {
        let seatID = SeatID(rawValue: 1)
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])
        let device = try #require(backend.binding(for: seatID))

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 81)
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        device.emit(.dataOffer(offerHandle1))
        let offerBinding = try #require(backend.offerBinding(for: offerHandle1))
        offerBinding.emit(.offer(MIMEType.uriList.rawValue))
        device.emit(.selection(offerHandle1))
        _ = manager.drainDataTransferEvents()

        sourceBinding.emit(.cancelled)

        #expect(manager.pendingCallbackError == nil)
        #expect(manager.seatSnapshots.first?.selectionOfferID == offerBinding.id)
        #expect(manager.seatSnapshots.first?.selectionSourceID == nil)
        #expect(manager.sourceSnapshots.isEmpty)
        #expect(manager.drainDataTransferEvents().isEmpty)
    }
}
