package struct TextInputEventQueue: DrainableEventQueue {
    private var pendingEvents: [TextInputEvent] = []

    package init() {
        // Starts with no pending text-input events.
    }

    package mutating func append(_ event: TextInputEvent) {
        pendingEvents.append(event)
    }

    package mutating func drain() -> [TextInputEvent] {
        pendingEvents.drain()
    }
}
