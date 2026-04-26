import Testing

@testable import WaylandRaw

@Suite
struct InputEventQueueTests {
    @Test
    func appendAndDrainPreservesOrderAndAssignsSequences() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 3)
        let pointerID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )

        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: nil,
                kind: .seat(
                    RawSeatEventSnapshot(
                        advertisedCapabilities: [.pointer],
                        activeCapabilities: [],
                        name: nil
                    )
                )
            )
        )
        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: pointerID,
                kind: .pointer(.axis(.frame))
            )
        )

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 2])
        #expect(events.map(\.seatID) == [seatID, seatID])
        #expect(events.map(\.deviceID) == [nil, pointerID])
        #expect(events[1].kind == .pointer(.axis(.frame)))
    }

    @Test
    func drainEmptiesQueueAndSequencesContinue() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 7)

        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: nil,
                kind: .seatRemoved
            )
        )
        #expect(queue.drain().map(\.sequence) == [1])
        #expect(queue.drain().isEmpty)

        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: nil,
                kind: .seatRemoved
            )
        )
        #expect(queue.drain().map(\.sequence) == [2])
    }
}
