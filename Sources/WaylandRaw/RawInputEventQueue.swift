import Synchronization

package protocol RawInputEventSink: AnyObject {
    func append(_ event: RawInputEventDraft)
}

package final class RawInputEventQueue: RawInputEventSink, Sendable {
    private struct State: Sendable {
        var nextSequence: UInt64 = 1
        var events: [RawInputEvent] = []
    }

    private let state = Mutex(State())

    package init() {
        // Starts empty and assigns sequence numbers on first append.
    }

    package func append(_ event: RawInputEventDraft) {
        state.withLock { state in
            state.events.append(
                RawInputEvent(
                    sequence: state.nextSequence,
                    seatID: event.seatID,
                    deviceID: event.deviceID,
                    kind: event.kind
                )
            )
            state.nextSequence += 1
        }
    }

    package func drain() -> [RawInputEvent] {
        state.withLock { state in
            defer { state.events.removeAll(keepingCapacity: true) }
            return state.events
        }
    }
}
