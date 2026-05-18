import WaylandRaw

package final class DataTransferEventQueue: DrainableEventQueue {
    private var pendingEvents: [DataTransferEvent] = []

    package init() {
        // Event queues start empty.
    }

    package func append(_ event: DataTransferEvent) {
        pendingEvents.append(event)
    }

    package func drain() -> [DataTransferEvent] {
        pendingEvents.drain()
    }
}
