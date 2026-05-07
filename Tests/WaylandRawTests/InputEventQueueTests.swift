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

    @Test
    func overflowClearsBufferedEventsAndEmitsDiagnostic() {
        let queue = RawInputEventQueue(capacity: RawInputQueueCapacity(unchecked: 1))
        let seatID = RawSeatID(rawValue: 9)

        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: nil,
                kind: .seatRemoved
            )
        )
        queue.append(
            RawInputEventDraft(
                seatID: seatID,
                deviceID: nil,
                kind: .seatRemoved
            )
        )

        let events = queue.drain()

        #expect(events.count == 1)
        #expect(events.first?.sequence == 2)
        #expect(
            events.first?.kind
                == .diagnostic(
                    RawInputDiagnostic(
                        .inputPipelineOverflow(
                            RawInputPipelineOverflow(stage: .rawInputQueue, capacity: 1)
                        )
                    )
                )
        )
    }
}

@Suite
struct InputEventQueueCoalescingTests {
    @Test
    func adjacentPointerMotionCoalescesToLatestEvent() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 10)
        let pointerID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )

        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 1, x: 10))
        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 2, x: 20))

        let events = queue.drain()

        #expect(events.count == 1)
        #expect(events.first?.sequence == 2)
        #expect(
            events.first?.kind
                == .pointer(
                    .motion(
                        RawPointerMotion(
                            time: 2,
                            x: WaylandFixed(rawValue: 20),
                            y: WaylandFixed(rawValue: 0)
                        )
                    )
                )
        )
    }

    @Test
    func pointerMotionCoalescingCanBeDisabled() {
        let queue = RawInputEventQueue(
            configuration: RawInputQueueConfiguration(coalescing: [])
        )
        let seatID = RawSeatID(rawValue: 20)
        let pointerID = RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)

        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 1, x: 10))
        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 2, x: 20))

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 2])
        #expect(events.count == 2)
    }

    @Test
    func pointerMotionCoalescingRequiresSameSeatAndDevice() {
        let queue = RawInputEventQueue()
        let firstSeatID = RawSeatID(rawValue: 21)
        let secondSeatID = RawSeatID(rawValue: 22)
        let firstPointerID = RawInputDeviceID(
            seatID: firstSeatID,
            kind: .pointer,
            generation: 1
        )
        let secondPointerID = RawInputDeviceID(
            seatID: firstSeatID,
            kind: .pointer,
            generation: 2
        )

        queue.append(
            pointerMotionDraft(seatID: firstSeatID, deviceID: firstPointerID, time: 1, x: 10)
        )
        queue.append(
            pointerMotionDraft(seatID: secondSeatID, deviceID: firstPointerID, time: 2, x: 20)
        )
        queue.append(
            pointerMotionDraft(seatID: firstSeatID, deviceID: secondPointerID, time: 3, x: 30)
        )

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 2, 3])
        #expect(events.count == 3)
    }

    @Test
    func pointerMotionDoesNotCoalesceAcrossBarrierEvent() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 11)
        let pointerID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )

        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 1, x: 10))
        queue.append(pointerButtonDraft(seatID: seatID, deviceID: pointerID))
        queue.append(pointerMotionDraft(seatID: seatID, deviceID: pointerID, time: 2, x: 20))

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 2, 3])
        #expect(events.count == 3)
    }

    @Test
    func adjacentTouchMotionCoalescesByTouchID() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 12)
        let touchID = RawInputDeviceID(
            seatID: seatID,
            kind: .touch,
            generation: 1
        )

        queue.append(touchMotionDraft(seatID: seatID, deviceID: touchID, touch: 4, time: 1, x: 10))
        queue.append(touchMotionDraft(seatID: seatID, deviceID: touchID, touch: 5, time: 2, x: 20))
        queue.append(touchMotionDraft(seatID: seatID, deviceID: touchID, touch: 5, time: 3, x: 30))

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 3])
        #expect(
            events.last?.kind
                == .touch(
                    .motion(
                        RawTouchMotion(
                            time: 3,
                            id: 5,
                            x: WaylandFixed(rawValue: 30),
                            y: WaylandFixed(rawValue: 0)
                        )
                    )
                )
        )
    }

    @Test
    func touchMotionCoalescingRequiresSameDeviceForSameTouchID() {
        let queue = RawInputEventQueue()
        let seatID = RawSeatID(rawValue: 23)
        let firstTouchID = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 1)
        let secondTouchID = RawInputDeviceID(seatID: seatID, kind: .touch, generation: 2)

        queue.append(
            touchMotionDraft(seatID: seatID, deviceID: firstTouchID, touch: 7, time: 1, x: 10)
        )
        queue.append(
            touchMotionDraft(seatID: seatID, deviceID: secondTouchID, touch: 7, time: 2, x: 20)
        )

        let events = queue.drain()

        #expect(events.map(\.sequence) == [1, 2])
        #expect(events.count == 2)
    }

    private func pointerMotionDraft(
        seatID: RawSeatID,
        deviceID: RawInputDeviceID,
        time: UInt32,
        x: Int32
    ) -> RawInputEventDraft {
        RawInputEventDraft(
            seatID: seatID,
            deviceID: deviceID,
            kind: .pointer(
                .motion(
                    RawPointerMotion(
                        time: time,
                        x: WaylandFixed(rawValue: x),
                        y: WaylandFixed(rawValue: 0)
                    )
                )
            )
        )
    }

    private func pointerButtonDraft(
        seatID: RawSeatID,
        deviceID: RawInputDeviceID
    ) -> RawInputEventDraft {
        RawInputEventDraft(
            seatID: seatID,
            deviceID: deviceID,
            kind: .pointer(
                .button(
                    RawPointerButton(
                        serial: 1,
                        time: 2,
                        button: 272,
                        state: .pressed
                    )
                )
            )
        )
    }

    private func touchMotionDraft(
        seatID: RawSeatID,
        deviceID: RawInputDeviceID,
        touch: Int32,
        time: UInt32,
        x: Int32
    ) -> RawInputEventDraft {
        RawInputEventDraft(
            seatID: seatID,
            deviceID: deviceID,
            kind: .touch(
                .motion(
                    RawTouchMotion(
                        time: time,
                        id: touch,
                        x: WaylandFixed(rawValue: x),
                        y: WaylandFixed(rawValue: 0)
                    )
                )
            )
        )
    }
}
