import Synchronization

package protocol RawInputEventSink: AnyObject {
    func append(_ event: RawInputEventDraft)
}

package struct RawInputCoalescing: OptionSet, Equatable, Sendable {
    package let rawValue: Int

    package init(rawValue coalescingRawValue: Int) {
        rawValue = coalescingRawValue
    }

    package static let pointerMotion = RawInputCoalescing(rawValue: 1 << 0)
    package static let touchMotion = RawInputCoalescing(rawValue: 1 << 1)
    package static let all: RawInputCoalescing = [.pointerMotion, .touchMotion]
}

package struct RawInputQueueCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    package let rawValue: Int

    package static let `default` = RawInputQueueCapacity(unchecked: 4_096)

    package init?(_ value: Int) {
        guard value > 0 else {
            return nil
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        precondition(value > 0, "Raw input event queue capacity must be positive")
        rawValue = value
    }

    package var description: String {
        String(rawValue)
    }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package struct RawInputQueueConfiguration: Equatable, Sendable {
    package var capacity: RawInputQueueCapacity
    package var coalescing: RawInputCoalescing

    package init(
        capacity eventCapacity: RawInputQueueCapacity = .default,
        pointerMotionCoalescing shouldCoalescePointerMotion: Bool = true,
        touchMotionCoalescing shouldCoalesceTouchMotion: Bool = true
    ) {
        capacity = eventCapacity
        coalescing = []
        if shouldCoalescePointerMotion {
            coalescing.insert(.pointerMotion)
        }
        if shouldCoalesceTouchMotion {
            coalescing.insert(.touchMotion)
        }
    }

    package init(
        coalescing coalescingPolicy: RawInputCoalescing,
        capacity eventCapacity: RawInputQueueCapacity = .default
    ) {
        capacity = eventCapacity
        coalescing = coalescingPolicy
    }
}

package final class RawInputEventQueue: RawInputEventSink, Sendable {
    package static let defaultCapacity = RawInputQueueCapacity.default

    private struct State: Sendable {
        var nextSequence: UInt64 = 1
        var events: [RawInputEvent] = []
    }

    private let configuration: RawInputQueueConfiguration
    private let state = Mutex(State())

    package init(capacity eventCapacity: RawInputQueueCapacity = defaultCapacity) {
        configuration = RawInputQueueConfiguration(capacity: eventCapacity)
    }

    package init(configuration queueConfiguration: RawInputQueueConfiguration) {
        configuration = queueConfiguration
    }

    package func append(_ event: RawInputEventDraft) {
        state.withLock { state in
            let materializedEvent = Self.materialize(event, sequence: state.nextSequence)
            state.nextSequence += 1

            if coalesce(materializedEvent, into: &state.events) {
                return
            }

            if state.events.count >= configuration.capacity.rawValue {
                appendOverflowDiagnostic(
                    for: event,
                    sequence: materializedEvent.sequence,
                    to: &state
                )
                return
            }

            state.events.append(materializedEvent)
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

    private func coalesce(
        _ event: RawInputEvent,
        into events: inout [RawInputEvent]
    ) -> Bool {
        guard let lastEvent = events.last else { return false }

        switch (lastEvent.kind, event.kind) {
        case (.pointer(.motion), .pointer(.motion)):
            guard configuration.coalescing.contains(.pointerMotion),
                lastEvent.seatID == event.seatID,
                lastEvent.deviceID == event.deviceID
            else { return false }
            events[events.count - 1] = event
            return true
        case (.touch(.motion(let previous)), .touch(.motion(let current))):
            guard configuration.coalescing.contains(.touchMotion),
                previous.id == current.id,
                lastEvent.seatID == event.seatID,
                lastEvent.deviceID == event.deviceID
            else { return false }
            events[events.count - 1] = event
            return true
        default:
            return false
        }
    }

    private func appendOverflowDiagnostic(
        for event: RawInputEventDraft,
        sequence eventSequence: UInt64,
        to state: inout State
    ) {
        state.events.removeAll(keepingCapacity: true)
        state.events.append(
            RawInputEvent(
                sequence: eventSequence,
                seatID: event.seatID,
                deviceID: event.deviceID,
                kind: .diagnostic(
                    RawInputDiagnostic(
                        .inputPipelineOverflow(
                            RawInputPipelineOverflow(
                                stage: .rawInputQueue,
                                capacity: configuration.capacity
                            )
                        )
                    )
                )
            )
        )
    }
}
