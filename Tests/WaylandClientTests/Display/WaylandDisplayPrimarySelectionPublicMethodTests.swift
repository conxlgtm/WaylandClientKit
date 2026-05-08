import Foundation
import Synchronization
import Testing

@testable import WaylandClient

@Suite("WaylandDisplay primary selection public methods")
struct WaylandDisplayPrimarySelectionTests {
    @Test
    func publicRequestPrimarySelectionPublishesPrimarySelectionEvent() async throws {
        let harness = try await primarySelectionDisplayHarness()
        let display = harness.display
        let handler = harness.handler
        var iterator = display.dataTransferEvents.makeAsyncIterator()
        let seatID = SeatID(rawValue: 11)
        let serial = InputSerial(rawValue: 17)
        let configuration = try PrimarySelectionSourceConfiguration.data(
            mimeType: .plainText,
            Data("primary".utf8)
        )

        let source = try await display.requestPrimarySelection(
            configuration,
            seatID: seatID,
            serial: serial
        )

        #expect(source.seatID == seatID)
        #expect(source.mimeTypes == [.plainText])
        #expect(
            handler.setRequests
                == [
                    PrimarySelectionSetRequest(
                        seatID: seatID,
                        serial: serial,
                        mimeTypes: [.plainText]
                    )
                ]
        )
        await expectPrimarySelectionEvent(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            ),
            from: &iterator
        )
        await display.close()
    }

    @Test
    func publicClearPrimarySelectionPublishesSourceCancellation() async throws {
        let harness = try await primarySelectionDisplayHarness()
        let display = harness.display
        let seatID = SeatID(rawValue: 12)
        let serial = InputSerial(rawValue: 18)
        var iterator = display.dataTransferEvents.makeAsyncIterator()
        let configuration = try PrimarySelectionSourceConfiguration.data(
            mimeType: .plainTextUTF8,
            Data("primary".utf8)
        )
        let source = try await display.requestPrimarySelection(
            configuration,
            seatID: seatID,
            serial: serial
        )
        await expectPrimarySelectionEvent(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            ),
            from: &iterator
        )

        try await source.requestClear(serial: serial)

        await expectPrimarySelectionEvent(
            .primarySelectionSourceCancelled(source.identity),
            from: &iterator
        )
        await expectPrimarySelectionEvent(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            ),
            from: &iterator
        )
        await display.close()
    }

    @Test
    func publicPrimarySelectionOfferReceiveUsesPrimarySelectionPath() async throws {
        let harness = try await primarySelectionDisplayHarness()
        let display = harness.display
        let handler = harness.handler
        let seatID = SeatID(rawValue: 13)
        let offerID = DataOfferID(rawValue: 19)
        handler.nextOffer = try DataOfferSnapshot(
            id: offerID,
            role: .selection(seatID: seatID),
            mimeTypes: [.plainText]
        )

        let offer = try await display.primarySelectionOffer(for: seatID)
        let primaryOffer = try #require(offer)
        var descriptor = try await primaryOffer.receive(.plainText)

        try descriptor.close()
        #expect(
            handler.receiveRequests
                == [
                    PrimarySelectionReceiveRequest(
                        offerID: offerID,
                        mimeType: .plainText
                    )
                ]
        )
        await display.close()
    }
}

private func primarySelectionDisplayHarness() async throws -> (
    display: WaylandDisplay,
    handler: RecordingDisplayPrimarySelectionHandler
) {
    try await WaylandDisplay.primarySelectionTestHarness { eventHub in
        RecordingDisplayPrimarySelectionHandler(eventHub: eventHub)
    }
}

private struct PrimarySelectionSetRequest: Equatable, Sendable {
    let seatID: SeatID
    let serial: InputSerial
    let mimeTypes: [MIMEType]
}

private struct PrimarySelectionClearRequest: Equatable, Sendable {
    let sourceID: DataSourceID?
    let seatID: SeatID
    let serial: InputSerial
}

private struct PrimarySelectionReceiveRequest: Equatable, Sendable {
    let offerID: DataOfferID
    let mimeType: MIMEType
}

private final class RecordingDisplayPrimarySelectionHandler:
    WaylandDisplayPrimarySelectionHandling, Sendable
{
    let eventHub: DisplayEventHub

    private let state = Mutex(RecordingDisplayPrimarySelectionState())

    var nextOffer: DataOfferSnapshot? {
        get { state.withLock(\.nextOffer) }
        set { state.withLock { $0.nextOffer = newValue } }
    }

    var setRequests: [PrimarySelectionSetRequest] {
        state.withLock(\.setRequests)
    }

    var receiveRequests: [PrimarySelectionReceiveRequest] {
        state.withLock(\.receiveRequests)
    }

    init(eventHub displayEventHub: DisplayEventHub) {
        eventHub = displayEventHub
    }

    func primarySelectionOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        let offer = state.withLock(\.nextOffer)
        guard let offer else {
            return nil
        }
        guard offer.role.seatID == seatID else {
            throw DataTransferError.mismatchedOfferSeat(
                offer: .primarySelection(PrimarySelectionOfferIdentity(offer.id)),
                expected: seatID,
                actual: offer.role.seatID
            )
        }

        return offer
    }

    func receivePrimarySelectionOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        state.withLock { state in
            state.receiveRequests.append(
                PrimarySelectionReceiveRequest(offerID: offerID, mimeType: mimeType)
            )
        }
        return try OwnedFileDescriptor(adopting: 200) { _ in 0 }
    }

    func setPrimarySelection(
        _ configuration: PrimarySelectionSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> DataSourceSnapshot {
        let source = try state.withLock { state in
            state.setRequests.append(
                PrimarySelectionSetRequest(
                    seatID: seatID,
                    serial: serial,
                    mimeTypes: configuration.mimeTypes
                )
            )
            let sourceID = DataSourceID(rawValue: state.nextSourceRawValue)
            state.nextSourceRawValue += 1
            let source = try DataSourceSnapshot(
                id: sourceID,
                seatID: seatID,
                mimeTypes: configuration.mimeTypes
            )
            state.activeSource = source
            return source
        }
        eventHub.publishDataTransfer(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            )
        )
        return source
    }

    func clearPrimarySelection(seatID: SeatID, serial: InputSerial) throws {
        state.withLock { state in
            state.clearRequests.append(
                PrimarySelectionClearRequest(
                    sourceID: nil,
                    seatID: seatID,
                    serial: serial
                )
            )
            state.activeSource = nil
        }
        eventHub.publishDataTransfer(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            )
        )
    }

    func clearPrimarySelection(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try state.withLock { state in
            state.clearRequests.append(
                PrimarySelectionClearRequest(
                    sourceID: sourceID,
                    seatID: seatID,
                    serial: serial
                )
            )
            guard state.activeSource?.id == sourceID else {
                throw DataTransferError.sourceCancelled
            }

            state.activeSource = nil
        }
        eventHub.publishDataTransfer(
            .primarySelectionSourceCancelled(PrimarySelectionSourceIdentity(sourceID))
        )
        eventHub.publishDataTransfer(
            .primarySelectionChanged(
                PrimarySelectionEvent(seatID: seatID, offerID: nil)
            )
        )
    }
}

private struct RecordingDisplayPrimarySelectionState: Sendable {
    var nextOffer: DataOfferSnapshot?
    var setRequests: [PrimarySelectionSetRequest] = []
    var clearRequests: [PrimarySelectionClearRequest] = []
    var receiveRequests: [PrimarySelectionReceiveRequest] = []
    var nextSourceRawValue: UInt64 = 1
    var activeSource: DataSourceSnapshot?
}

private func expectPrimarySelectionEvent(
    _ expectedEvent: DataTransferEvent,
    from iterator: inout DataTransferEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected primary-selection event, got \(error)")
    }
}
