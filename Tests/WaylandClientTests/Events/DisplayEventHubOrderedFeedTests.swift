import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubOrderedFeedTests {
    @Test
    func onePumpPublishesEachFamilyOnceInOrderToIndependentRootSubscribers() async {
        let hub = DisplayEventHub()
        let outputEvent = DisplayEvent.outputRemoved(OutputID(rawValue: 1))
        let inputEvent = InputEvent(
            sequence: 2,
            seatID: SeatID(rawValue: 3),
            target: .display,
            kind: .seat(.removed)
        )
        let textInputEvent = TextInputEvent.transaction(
            TextInputTransaction(
                seatID: SeatID(rawValue: 3),
                target: .focusless,
                serial: TextInputCommitSerial(rawValue: 4),
                matchesLatestCommit: true,
                preedit: nil,
                deletion: nil,
                committedText: "text",
                action: nil
            )
        )
        let dataTransferEvent = DataTransferEvent.clipboardSelectionChanged(
            ClipboardSelectionEvent(
                seatID: SeatID(rawValue: 3),
                offerID: DataOfferID(rawValue: 5)
            )
        )
        let expected = [
            outputEvent,
            .input(inputEvent),
            .textInput(textInputEvent),
            .dataTransfer(dataTransferEvent),
        ]
        var firstIterator = hub.displayEvents().makeAsyncIterator()
        var secondIterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(outputEvent)
        hub.publishInput(inputEvent)
        hub.publishTextInput(textInputEvent)
        hub.publishDataTransfer(dataTransferEvent)
        hub.finish()

        let firstSequence = await drainDisplayEvents(from: &firstIterator)
        let secondSequence = await drainDisplayEvents(from: &secondIterator)
        #expect(firstSequence == expected)
        #expect(secondSequence == expected)
    }
}

private func drainDisplayEvents(
    from iterator: inout DisplayEventsIterator
) async -> [DisplayEvent] {
    var events: [DisplayEvent] = []
    do {
        while let event = try await iterator.next() {
            events.append(event)
        }
    } catch {
        Issue.record("Expected normally terminated display stream, got \(error)")
    }
    return events
}
