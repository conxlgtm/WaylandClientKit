import Synchronization

package protocol RawInputEventSink: AnyObject {
    func append(_ event: RawInputEventDraft)
}

package final class RawInputEventQueue: RawInputEventSink, Sendable {
    package static let defaultCapacity = 4_096

    private struct State: Sendable {
        var nextSequence: UInt64 = 1
        var events: [RawInputEvent] = []
    }

    private let capacity: Int
    private let state = Mutex(State())

    package init(capacity eventCapacity: Int = defaultCapacity) {
        precondition(eventCapacity > 0, "Raw input event queue capacity must be positive")
        capacity = eventCapacity
    }

    package func append(_ event: RawInputEventDraft) {
        state.withLock { state in
            if state.events.count >= capacity {
                state.events.removeAll(keepingCapacity: true)
                state.events.append(
                    RawInputEvent(
                        sequence: state.nextSequence,
                        seatID: event.seatID,
                        deviceID: event.deviceID,
                        kind: .diagnostic(
                            RawInputDiagnostic(
                                operation: .queueOverflow,
                                message: "raw input queue exceeded capacity \(capacity)"
                            )
                        )
                    )
                )
                state.nextSequence += 1
                return
            }

            state.events.append(Self.materialize(event, sequence: state.nextSequence))
            state.nextSequence += 1
        }
    }

    package func drain() -> [RawInputEvent] {
        state.withLock { state in
            defer { state.events.removeAll(keepingCapacity: true) }
            return state.events
        }
    }

    private static func materialize(
        _ event: RawInputEventDraft,
        sequence: UInt64
    ) -> RawInputEvent {
        RawInputEvent(
            sequence: sequence,
            seatID: event.seatID,
            deviceID: event.deviceID,
            kind: event.kind
        )
    }
}
