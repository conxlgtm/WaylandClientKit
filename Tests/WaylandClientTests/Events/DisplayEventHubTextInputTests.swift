import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubTextInputTests {
    @Test
    func textInputEventsAreDeliveredOnDedicatedStream() async {
        let hub = DisplayEventHub()
        let expected = TextInputEvent.committed(
            TextInputCommitEvent(
                seatID: SeatID(rawValue: 2),
                text: "input"
            )
        )
        var iterator = hub.textInputEvents().makeAsyncIterator()

        hub.publishTextInput(expected)

        do {
            let event = try await iterator.next()
            #expect(event == expected)
        } catch {
            Issue.record("Expected text-input event, got \(error)")
        }
    }
}
