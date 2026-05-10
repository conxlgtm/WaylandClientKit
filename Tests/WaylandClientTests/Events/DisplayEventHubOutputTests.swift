import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubOutputTests {
    @Test
    func outputEventsPublishOnDisplayStream() async throws {
        let hub = DisplayEventHub()
        let snapshot = OutputSnapshot(
            id: OutputID(rawValue: 7),
            version: 4,
            geometry: nil,
            currentMode: nil,
            scale: try PositiveInt32(1),
            name: "HDMI-A-1",
            description: nil
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.outputChanged(snapshot))
        hub.publish(.outputRemoved(OutputID(rawValue: 8)))

        await expectOutputEvent(.outputChanged(snapshot), from: &iterator)
        await expectOutputEvent(.outputRemoved(OutputID(rawValue: 8)), from: &iterator)
    }

    @Test
    func windowOutputMembershipEventsPublishOnDisplayStream() async {
        let hub = DisplayEventHub()
        let event = WindowOutputMembershipEvent(
            windowID: WindowID(rawValue: 3),
            outputs: [OutputID(rawValue: 1), OutputID(rawValue: 2)]
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.windowOutputsChanged(event))

        await expectOutputEvent(.windowOutputsChanged(event), from: &iterator)
    }
}

private func expectOutputEvent(
    _ expectedEvent: DisplayEvent,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected output display event, got \(error)")
    }
}
