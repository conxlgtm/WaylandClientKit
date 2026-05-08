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
    func repeatedCapabilityMaskIsIdempotentWhenChildIsActive() throws {
        let seatID = RawSeatID(rawValue: 7)
        let old = try SeatState(
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
    func removingPointerCapabilityPlansPointerDestruction() throws {
        let seatID = RawSeatID(rawValue: 8)
        let old = try SeatState(
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
    func changingFromPointerKeyboardToKeyboardDestroysPointerOnly() throws {
        let seatID = RawSeatID(rawValue: 9)
        let old = try SeatState(
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
    func seatStateRejectsActiveCapabilityNotAdvertised() {
        #expect(
            throws: SeatStateError.activeCapabilityNotAdvertised(
                activeCapabilities: [.pointer],
                advertisedCapabilities: []
            )
        ) {
            _ = try SeatState(
                advertisedCapabilities: [],
                activeCapabilities: [.pointer]
            )
        }
    }

    @Test
    func propertySeatActiveCapabilitiesAreAlwaysSubsetOfAdvertisedCapabilities() {
        let seatID = RawSeatID(rawValue: 20)

        for advertisedRawValue in UInt32(0)...UInt32(7) {
            let advertised = SeatCapabilities(rawValue: advertisedRawValue)
            let plan = reduceSeatState(
                SeatState(),
                seatID: seatID,
                action: .capabilitiesChanged(advertised)
            )

            #expect(
                plan.nextState.activeCapabilities.isSubset(
                    of: plan.nextState.advertisedCapabilities
                )
            )
        }
    }

    @Test
    func pointerCreatedWithoutAdvertisedPointerIsRejected() {
        let seatID = RawSeatID(rawValue: 21)
        let plan = reduceSeatState(
            SeatState(),
            seatID: seatID,
            action: .pointerCreated
        )

        #expect(plan.effects.isEmpty)
        #expect(plan.nextState.activeCapabilities.isEmpty)
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
    func seatRemovalDestroysChildrenBeforeEmittingRemoval() throws {
        let seatID = RawSeatID(rawValue: 12)
        let old = try SeatState(
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
