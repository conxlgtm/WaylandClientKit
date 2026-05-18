package protocol DrainableEventQueue {
    associatedtype Event

    mutating func append(_ event: Event)
    mutating func drain() -> [Event]
}

extension DrainableEventQueue {
    package mutating func append<Events: Sequence>(
        contentsOf events: Events
    ) where Events.Element == Event {
        for event in events {
            append(event)
        }
    }
}

package struct EventAndDiagnostics<Event, Diagnostic> {
    package var events: [Event]
    package var diagnostics: [Diagnostic]

    package init(events drainedEvents: [Event], diagnostics drainedDiagnostics: [Diagnostic]) {
        events = drainedEvents
        diagnostics = drainedDiagnostics
    }
}
