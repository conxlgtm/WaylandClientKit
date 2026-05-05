import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubDataTransferTests {
    @Test
    func dataTransferStreamReceivesPublishedEvents() async {
        let hub = DisplayEventHub()
        var iterator = hub.dataTransferEvents().makeAsyncIterator()
        let event = DataTransferEvent.selectionChanged(
            ClipboardSelectionEvent(
                seatID: SeatID(rawValue: 1),
                offerID: DataOfferID(rawValue: 2)
            )
        )

        hub.publishDataTransfer(event)

        await expectDataTransferNext(event, from: &iterator)
    }

    @Test
    func dataTransferSubscriberOverflowUsesConfiguredCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: try EventStreamConfiguration(dataTransferEventCapacity: 1)
        )
        let stream = hub.dataTransferEvents()

        hub.publishDataTransfer(
            .sourceCancelled(ClipboardSourceIdentity(DataSourceID(rawValue: 1)))
        )
        hub.publishDataTransfer(
            .sourceCancelled(ClipboardSourceIdentity(DataSourceID(rawValue: 2)))
        )

        var iterator = stream.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            Issue.record("Expected configured data transfer event overflow")
        } catch {
            #expect(
                error
                    == .eventSubscriberOverflow(
                        stream: .dataTransferEvents,
                        capacity: 1
                    )
            )
        }
    }

    @Test
    func fatalInternalInvariantTerminatesDataTransferStream() async {
        let hub = DisplayEventHub()
        var iterator = hub.dataTransferEvents().makeAsyncIterator()
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("listener state lost")
        )

        hub.finish(throwing: error)

        await expectFailure(error, from: &iterator)
    }
}

private func expectDataTransferNext(
    _ expectedEvent: DataTransferEvent,
    from iterator: inout DataTransferEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected data transfer event, got \(error)")
    }
}

private func expectFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DataTransferEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected data transfer stream failure")
    } catch { #expect(error == expectedError) }
}
