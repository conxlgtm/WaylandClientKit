import Foundation
import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct InputSerialActionTests {
    @Test
    func registeredActionsRunForPublishedInputEventsInInstallOrder() {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let recorder = InputSerialActionRecorder()

        _ = core.installInputSerialAction { event, _ in
            recorder.record("first:\(event.sequence)")
        }
        _ = core.installInputSerialAction { event, _ in
            recorder.record("second:\(event.sequence)")
        }

        core.publishInputEvents([inputEvent(sequence: 1), inputEvent(sequence: 2)])

        #expect(
            recorder.values == [
                "first:1",
                "second:1",
                "first:2",
                "second:2",
            ]
        )
    }

    @Test
    func removedActionDoesNotRunForPublishedInputEvents() {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let recorder = InputSerialActionRecorder()
        let actionID = core.installInputSerialAction { event, _ in
            recorder.record("removed:\(event.sequence)")
        }

        core.removeInputSerialAction(actionID)
        core.publishInputEvents([inputEvent(sequence: 1)])

        #expect(recorder.values.isEmpty)
    }
}

// SAFETY: Recorder state is private and every access is protected by NSLock.
private final class InputSerialActionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }
}

private func inputEvent(sequence: UInt64) -> InputEvent {
    InputEvent(
        sequence: sequence,
        seatID: SeatID(rawValue: 1),
        target: .surface(.window(WindowID(rawValue: 1))),
        kind: .pointer(
            .button(
                PointerButtonEvent(
                    serial: InputSerial(rawValue: UInt32(sequence)),
                    time: WaylandTimestampMilliseconds(rawValue: 1),
                    button: PointerButtonCode(rawValue: 0x110),
                    state: .pressed
                )
            )
        )
    )
}
