import Testing

@testable import WaylandRaw

@Suite
struct SeatStateTests {
    @Test
    func addingPointerCapabilityPlansPointerCreation() {
        let seatID = RawSeatID(rawValue: 7)
        let old = SeatState()
        let pointerID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )

        let plan = reduceSeatState(
            old,
            seatID: seatID,
            action: .capabilitiesChanged([.pointer])
        )

        #expect(
            plan.effects == [
                .createPointer(pointerID),
                .emitSeatSnapshot,
            ])
        #expect(plan.nextState.advertisedCapabilities == [.pointer])
        #expect(plan.nextState.activeCapabilities == [.pointer])
        #expect(plan.nextState.pointerGeneration == 2)
    }

    @Test
    func repeatedCapabilityMaskIsIdempotentWhenChildIsActive() {
        let seatID = RawSeatID(rawValue: 7)
        let old = SeatState(
            advertisedCapabilities: [.pointer],
            activeCapabilities: [.pointer],
            pointerGeneration: 2
        )

        let plan = reduceSeatState(
            old,
            seatID: seatID,
            action: .capabilitiesChanged([.pointer])
        )

        #expect(plan.effects.isEmpty)
        #expect(plan.nextState == old)
    }

    @Test
    func removingPointerCapabilityPlansPointerDestruction() {
        let seatID = RawSeatID(rawValue: 8)
        let old = SeatState(
            advertisedCapabilities: [.pointer],
            activeCapabilities: [.pointer],
            pointerGeneration: 2
        )
        let pointerID = RawInputDeviceID(
            seatID: seatID,
            kind: .pointer,
            generation: 1
        )

        let plan = reduceSeatState(
            old,
            seatID: seatID,
            action: .capabilitiesChanged([])
        )

        #expect(
            plan.effects == [
                .destroyPointer(pointerID),
                .emitSeatSnapshot,
            ])
        #expect(plan.nextState.advertisedCapabilities.isEmpty)
        #expect(plan.nextState.activeCapabilities.isEmpty)
    }

    @Test
    func changingFromPointerKeyboardToKeyboardDestroysPointerOnly() {
        let seatID = RawSeatID(rawValue: 9)
        let old = SeatState(
            advertisedCapabilities: [.pointer, .keyboard],
            activeCapabilities: [.pointer, .keyboard],
            pointerGeneration: 2,
            keyboardGeneration: 2
        )

        let plan = reduceSeatState(
            old,
            seatID: seatID,
            action: .capabilitiesChanged([.keyboard])
        )

        #expect(
            plan.effects == [
                .destroyPointer(
                    RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)
                ),
                .emitSeatSnapshot,
            ])
        #expect(plan.nextState.activeCapabilities == [.keyboard])
    }

    @Test
    func unknownCapabilityBitsAreAdvertisedButDoNotCreateChildren() {
        let seatID = RawSeatID(rawValue: 10)
        let future = SeatCapabilities(rawValue: 0x80)

        let plan = reduceSeatState(
            SeatState(),
            seatID: seatID,
            action: .capabilitiesChanged(future)
        )

        #expect(plan.effects == [.emitSeatSnapshot])
        #expect(plan.nextState.advertisedCapabilities == future)
        #expect(plan.nextState.activeCapabilities.isEmpty)
    }

    @Test
    func createFailurePreservesAdvertisedCapabilitiesAndRemovesActiveChild() {
        let seatID = RawSeatID(rawValue: 11)
        let planned = reduceSeatState(
            SeatState(),
            seatID: seatID,
            action: .capabilitiesChanged([.pointer, .keyboard])
        ).nextState

        let failed = reduceSeatState(
            planned,
            seatID: seatID,
            action: .pointerCreateFailed
        )

        #expect(failed.effects == [.emitSeatSnapshot])
        #expect(failed.nextState.advertisedCapabilities == [.pointer, .keyboard])
        #expect(failed.nextState.activeCapabilities == [.keyboard])
        #expect(failed.nextState.pointerGeneration == 2)
    }

    @Test
    func seatRemovalDestroysChildrenBeforeEmittingRemoval() {
        let seatID = RawSeatID(rawValue: 12)
        let old = SeatState(
            advertisedCapabilities: [.pointer, .keyboard, .touch],
            activeCapabilities: [.pointer, .keyboard, .touch],
            pointerGeneration: 2,
            keyboardGeneration: 2,
            touchGeneration: 2
        )

        let plan = reduceSeatState(old, seatID: seatID, action: .removed)

        #expect(
            plan.effects == [
                .destroyTouch(RawInputDeviceID(seatID: seatID, kind: .touch, generation: 1)),
                .destroyKeyboard(RawInputDeviceID(seatID: seatID, kind: .keyboard, generation: 1)),
                .destroyPointer(RawInputDeviceID(seatID: seatID, kind: .pointer, generation: 1)),
                .emitSeatRemoved,
            ])
        #expect(plan.nextState.advertisedCapabilities.isEmpty)
        #expect(plan.nextState.activeCapabilities.isEmpty)
    }
}
