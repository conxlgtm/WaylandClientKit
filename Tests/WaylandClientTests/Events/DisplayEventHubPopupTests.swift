import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubPopupTests {
    @Test
    func popupLifecycleEventsPublishOnDisplayStream() async {
        let hub = DisplayEventHub()
        let dismissed = PopupLifecycleEvent(
            popup: PopupID(rawValue: 7),
            parentWindowID: WindowID(rawValue: 3)
        )
        let closed = PopupLifecycleEvent(
            popup: PopupID(rawValue: 8),
            parentWindowID: WindowID(rawValue: 3)
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.popupDismissed(dismissed))
        hub.publish(.popupClosed(closed))

        await expectPopupEvent(.popupDismissed(dismissed), from: &iterator)
        await expectPopupEvent(.popupClosed(closed), from: &iterator)
    }

    @Test
    func popupRedrawRequestsPublishPopupTargetsOnDisplayStream() async {
        let hub = DisplayEventHub()
        let popup = PopupLifecycleEvent(
            popup: PopupID(rawValue: 7),
            parentWindowID: WindowID(rawValue: 3)
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        hub.publish(.popupRedrawRequested(popup))

        await expectPopupEvent(.popupRedrawRequested(popup), from: &iterator)
    }

    @Test
    func installedPopupRedrawCallbackPublishesPopupRedrawTarget() async throws {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let popupID = PopupID(rawValue: 7)
        let parentWindowID = WindowID(rawValue: 3)
        let expected = PopupLifecycleEvent(
            popup: popupID,
            parentWindowID: parentWindowID
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        let callbacks = core.popupEventCallbacks(
            popupID: popupID,
            parentWindowID: parentWindowID
        )
        callbacks.onRedrawRequested()

        await expectPopupEvent(.popupRedrawRequested(expected), from: &iterator)
    }
}

private func expectPopupEvent(
    _ expectedEvent: DisplayEvent,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        let event = try await iterator.next()
        #expect(event == expectedEvent)
    } catch {
        Issue.record("Expected popup display event, got \(error)")
    }
}
