import Foundation
import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct DataTransferManagerSourceRuntimeTests {
    private let seatID = SeatID(rawValue: 1)

    @Test
    func sourceRuntimeBindingIDMustMatchSourceID() throws {
        let backend = RecordingDataTransferBackend()
        backend.sourceBindingIDOverride = DataSourceID(rawValue: 99)
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        #expect(
            throws: DataTransferManagerInvariantViolation.sourceBindingIDMismatch(
                expected: DataSourceID(rawValue: 1),
                actual: DataSourceID(rawValue: 99)
            )
        ) {
            _ = try manager.setSelectionSource(
                seatID: seatID,
                mimeTypes: [.plainText],
                serial: InputSerial(rawValue: 1)
            )
        }
        #expect(backend.sourceBinding(for: DataSourceID(rawValue: 1))?.destroyCount == 1)
        #expect(manager.sourceSnapshots.isEmpty)
    }

    @Test
    func pendingSourceSendRequestCannotOutliveSourceAfterSeatRemoval() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 2),
            payloads: try DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 301))
        try manager.checkInvariantsForTesting()
        try manager.synchronizeSeats([])

        #expect(backend.closedDescriptors == [301])
        #expect(manager.drainSourceSendRequests().isEmpty)
        try manager.checkInvariantsForTesting()
    }

    @Test
    func cancelledSourceCannotReceiveSendRequest() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        try manager.synchronizeSeats([seatID])

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 3),
            payloads: try DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))

        sourceBinding.emit(.cancelled)
        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 302))

        #expect(backend.closedDescriptors == [302])
        #expect(manager.drainSourceSendRequests().isEmpty)
        #expect(
            throws: DataTransferCallbackFailure(
                context: .dataSource(ClipboardSourceIdentity(source.id)),
                error: .unknownSourceIdentity(ClipboardSourceIdentity(source.id))
            )
        ) {
            try manager.throwPendingCallbackErrorIfAny()
        }
    }

    @Test
    func dataTransferTransitionSequenceMaintainsRuntimeInvariants() throws {
        let backend = RecordingDataTransferBackend()
        let manager = DataTransferManager(backend: backend)
        let offerHandle = RawDataOfferHandle(uncheckedRawValue: 0xDA7A_7001)

        try manager.synchronizeSeats([seatID])
        try manager.checkInvariantsForTesting()
        let device = try #require(backend.binding(for: seatID))

        let source = try manager.setSelectionSource(
            seatID: seatID,
            mimeTypes: [.plainText],
            serial: InputSerial(rawValue: 4),
            payloads: try DataTransferSourcePayloadSet(
                data: [.plainText: Data("clipboard".utf8)]
            )
        )
        let sourceBinding = try #require(backend.sourceBinding(for: source.id))
        sourceBinding.emit(.send(mimeType: MIMEType.plainText.rawValue, fd: 401))
        try manager.checkInvariantsForTesting()

        device.emit(.dataOffer(offerHandle))
        let offerBinding = try #require(backend.offerBinding(for: offerHandle))
        offerBinding.emit(.offer(MIMEType.uriList.rawValue))
        device.emit(.selection(offerHandle))
        try manager.checkInvariantsForTesting()

        #expect(sourceBinding.destroyCount == 1)
        #expect(backend.closedDescriptors == [401])
        #expect(manager.drainSourceSendRequests().isEmpty)
        #expect(manager.seatSnapshots.first?.selectionOfferID == offerBinding.id)

        device.emit(.selection(nil))
        try manager.checkInvariantsForTesting()
        #expect(offerBinding.destroyCount == 1)

        try manager.synchronizeSeats([])
        try manager.checkInvariantsForTesting()
        #expect(device.releaseCount == 1)
        #expect(manager.seatSnapshots.isEmpty)
    }
}
