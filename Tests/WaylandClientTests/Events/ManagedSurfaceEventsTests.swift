import Testing

@testable import WaylandClient

@Suite
struct ManagedSurfaceEventsTests {
    @Test
    func displayEventsPreserveManagedSurfaceRedrawOrder() async {
        let hub = DisplayEventHub()
        var iterator = hub.displayEvents().makeAsyncIterator()
        let identities: [ManagedSurfaceIdentity] = [
            .window(WindowID(rawValue: 1)),
            .popup(PopupSurfaceIdentity(PopupID(rawValue: 2))),
            .subsurface(SubsurfaceIdentity(SubsurfaceID(rawValue: 3))),
        ]

        for identity in identities {
            hub.publish(.redrawRequested(identity))
        }

        do {
            for identity in identities {
                #expect(try await iterator.next() == .redrawRequested(identity))
            }
        } catch {
            Issue.record("Expected managed-surface redraw events, got \(error)")
        }
    }

    @Test
    func presentationEventsFilterByManagedSurfaceIdentity() async {
        let hub = DisplayEventHub()
        let window: ManagedSurfaceIdentity = .window(WindowID(rawValue: 1))
        let popup: ManagedSurfaceIdentity = .popup(
            PopupSurfaceIdentity(PopupID(rawValue: 2))
        )
        let expected = SurfacePresentationFeedback.discarded(
            SurfacePresentationIdentity(rawValue: 9)
        )
        var filteredIterator = hub.managedSurfacePresentationEvents(
            surface: popup
        ).makeAsyncIterator()
        var displayIterator = hub.displayEvents().makeAsyncIterator()
        let other = ManagedSurfacePresentationEvent(
            surface: window,
            feedback: .discarded(SurfacePresentationIdentity(rawValue: 8))
        )
        let matching = ManagedSurfacePresentationEvent(
            surface: popup,
            feedback: expected
        )

        hub.publishPresentation(other)
        hub.publishPresentation(matching)

        do {
            #expect(try await filteredIterator.next() == expected)
            #expect(try await displayIterator.next() == .presentation(other))
            #expect(try await displayIterator.next() == .presentation(matching))
        } catch {
            Issue.record("Expected managed-surface presentation events, got \(error)")
        }
    }
}
