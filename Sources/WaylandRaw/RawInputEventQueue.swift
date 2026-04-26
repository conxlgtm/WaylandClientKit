package protocol RawInputEventSink: AnyObject {
    func append(_ event: RawInputEventDraft)
}

package final class RawInputEventQueue: RawInputEventSink {
    private var nextSequence: UInt64 = 1
    private var events: [RawInputEvent] = []

    package init() {
        // Starts empty and assigns sequence numbers on first append.
    }

    package func append(_ event: RawInputEventDraft) {
        events.append(
            RawInputEvent(
                sequence: nextSequence,
                seatID: event.seatID,
                deviceID: event.deviceID,
                kind: event.kind
            )
        )
        nextSequence += 1
    }

    package func drain() -> [RawInputEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }
}
