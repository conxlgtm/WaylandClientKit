import Testing

@testable import WaylandClient

@Suite
struct DisplayEventHubPresentationTests {
    @Test
    func presentationEventsAreScopedToManagedSurface() async {
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
        let popup: ManagedSurfaceIdentity = .popup(
            PopupSurfaceIdentity(PopupID(rawValue: 2))
        )
        var iterator = hub.managedSurfacePresentationEvents(
            surface: popup
        ).makeAsyncIterator()
        var displayIterator = hub.displayEvents().makeAsyncIterator()

        let otherSurfaceEvent = ManagedSurfacePresentationEvent(
            surface: .window(WindowID(rawValue: 1)),
            feedback: .discarded(SurfacePresentationIdentity(rawValue: 99))
        )
        let expectedPopupEvent = ManagedSurfacePresentationEvent(
            surface: popup,
            feedback: expected
        )
        hub.publishPresentation(otherSurfaceEvent)
        hub.publishPresentation(expectedPopupEvent)

        do {
            let event = try await iterator.next()
            #expect(event == expected)
            let firstDisplayEvent = try await displayIterator.next()
            let secondDisplayEvent = try await displayIterator.next()
            #expect(firstDisplayEvent == .presentation(otherSurfaceEvent))
            #expect(secondDisplayEvent == .presentation(expectedPopupEvent))
        } catch {
            Issue.record("Expected presentation event, got \(error)")
        }
    }

    @Test
    func presentationSubscriberOverflowUsesConfiguredCapacity() async throws {
        let hub = DisplayEventHub(
            configuration: EventStreamConfiguration(
                presentationEventCapacity: try PositiveInt(1))
        )
        let surface: ManagedSurfaceIdentity = .subsurface(
            SubsurfaceIdentity(SubsurfaceID(rawValue: 4))
        )
        var iterator = hub.managedSurfacePresentationEvents(
            surface: surface
        ).makeAsyncIterator()

        hub.publishPresentation(
            ManagedSurfacePresentationEvent(
                surface: surface,
                feedback: .discarded(SurfacePresentationIdentity(rawValue: 1))
            )
        )
        hub.publishPresentation(
            ManagedSurfacePresentationEvent(
                surface: surface,
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
