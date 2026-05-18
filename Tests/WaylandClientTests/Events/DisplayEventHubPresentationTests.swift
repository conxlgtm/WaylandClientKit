import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubPresentationTests {
    @Test
    func presentationEventsAreScopedToWindow() async {
        let hub = DisplayEventHub()
        let expected = SurfacePresentationFeedback.presented(
            PresentationFeedback(
                surface: SurfacePresentationIdentity(rawValue: 1),
                timestamp: PresentationTimestamp(seconds: 10, nanoseconds: 20),
                refreshNanoseconds: nil,
                sequence: PresentationSequence(value: 2),
                flags: [.vsync],
                synchronizedOutput: OutputID(rawValue: 3)
            )
        )
        var iterator = hub.windowPresentationEvents(
            windowID: WindowID(rawValue: 2)
        ).makeAsyncIterator()

        hub.publishPresentation(
            WindowPresentationEvent(
                windowID: WindowID(rawValue: 1),
                feedback: .discarded(SurfacePresentationIdentity(rawValue: 99))
            )
        )
        hub.publishPresentation(
            WindowPresentationEvent(
                windowID: WindowID(rawValue: 2),
                feedback: expected
            )
        )

        do {
            let event = try await iterator.next()
            #expect(event == expected)
        } catch {
            Issue.record("Expected presentation event, got \(error)")
        }
    }

    @Test
    func presentationSubscriberOverflowUsesConfiguredCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: try EventStreamConfiguration(presentationEventCapacity: 1)
        )
        let windowID = WindowID(rawValue: 4)
        var iterator = hub.windowPresentationEvents(windowID: windowID).makeAsyncIterator()

        hub.publishPresentation(
            WindowPresentationEvent(
                windowID: windowID,
                feedback: .discarded(SurfacePresentationIdentity(rawValue: 1))
            )
        )
        hub.publishPresentation(
            WindowPresentationEvent(
                windowID: windowID,
                feedback: .discarded(SurfacePresentationIdentity(rawValue: 2))
            )
        )

        do {
            _ = try await iterator.next()
            Issue.record("Expected presentation event overflow")
        } catch {
            #expect(
                error
                    == .eventSubscriberOverflow(
                        stream: .presentationEvents,
                        capacity: 1
                    )
            )
        }
    }
}
