package final class DataTransferEventQueue {
    private var pendingEvents: [DataTransferEvent] = []

    package init() {
        // Event queues start empty.
    }

    package func append(_ event: DataTransferEvent) {
        pendingEvents.append(event)
    }

    package func drain() -> [DataTransferEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }
}
