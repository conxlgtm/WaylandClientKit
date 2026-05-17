package struct TextInputEventQueue {
    private var pendingEvents: [TextInputEvent] = []

    package init() {}

    package mutating func append(_ event: TextInputEvent) {
        pendingEvents.append(event)
    }

    package mutating func append(contentsOf events: [TextInputEvent]) {
        pendingEvents.append(contentsOf: events)
    }

    package mutating func drain() -> [TextInputEvent] {
        pendingEvents.drain()
    }
}
