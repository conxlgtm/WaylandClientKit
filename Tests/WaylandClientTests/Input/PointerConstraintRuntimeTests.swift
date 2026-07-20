import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerConstraintRuntimeTests {
    @Test
    func oneShotUnlockedPublishesDefunctAndDestroysManagedConstraintAndRegion() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(109)
        let seatID = SeatID(rawValue: 12)
        let rawSeatID = RawSeatID(seatID)
        let id = PointerConstraintID(rawValue: 1, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(109), kind: .locked)
        let recorder = PointerConstraintDestroyRecorder(id: id, rawIdentity: rawIdentity)

        runtime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: recorder.managedConstraint(),
            lifetime: .oneShot
        )

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: rawSeatID,
                    event: .locked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .activated(id)
        )
        #expect(recorder.constraintDestroyCount == 0)
        #expect(recorder.regionDestroyCount == 0)

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 2,
                    seatID: rawSeatID,
                    event: .unlocked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .defunctOneShot(id)
        )
        #expect(recorder.constraintDestroyCount == 1)
        #expect(recorder.regionDestroyCount == 1)
        #expect(runtime.lifecycle(for: id) == nil)
        #expect(throws: PointerCaptureError.unknownPointerConstraint(id)) {
            try runtime.destroyPointerConstraint(id)
        }

        try runtime.preflight(surfaceID: surfaceID, seatID: seatID)
        #expect(recorder.constraintDestroyCount == 1)
        #expect(recorder.regionDestroyCount == 1)
    }

    @Test
    func oneShotUnconfinedPublishesDefunctAndDestroysManagedConstraintAndRegion() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(110)
        let seatID = SeatID(rawValue: 13)
        let rawSeatID = RawSeatID(seatID)
        let id = PointerConstraintID(rawValue: 2, kind: .confined)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(110), kind: .confined)
        let recorder = PointerConstraintDestroyRecorder(id: id, rawIdentity: rawIdentity)

        runtime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: recorder.managedConstraint(),
            lifetime: .oneShot
        )

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: rawSeatID,
                    event: .confined(rawIdentity, surfaceID: surfaceID)
                )
            ) == .activated(id)
        )
        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 2,
                    seatID: rawSeatID,
                    event: .unconfined(rawIdentity, surfaceID: surfaceID)
                )
            ) == .defunctOneShot(id)
        )
        #expect(recorder.constraintDestroyCount == 1)
        #expect(recorder.regionDestroyCount == 1)
        #expect(runtime.lifecycle(for: id) == nil)
    }

    @Test
    func persistentUnlockedPublishesInactiveAndDoesNotDestroyManagedConstraint() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(111)
        let seatID = SeatID(rawValue: 14)
        let rawSeatID = RawSeatID(seatID)
        let id = PointerConstraintID(rawValue: 3, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(111), kind: .locked)
        let recorder = PointerConstraintDestroyRecorder(id: id, rawIdentity: rawIdentity)

        runtime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: recorder.managedConstraint(),
            lifetime: .persistent
        )

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: rawSeatID,
                    event: .locked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .activated(id)
        )
        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 2,
                    seatID: rawSeatID,
                    event: .unlocked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .inactivePersistent(id)
        )
        #expect(recorder.constraintDestroyCount == 0)
        #expect(recorder.regionDestroyCount == 0)
        #expect(runtime.lifecycle(for: id) == .inactivePersistent)
        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try runtime.preflight(surfaceID: surfaceID, seatID: seatID)
        }

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 3,
                    seatID: rawSeatID,
                    event: .locked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .activated(id)
        )
        #expect(runtime.lifecycle(for: id) == .active)

        try runtime.destroyPointerConstraint(id)
        #expect(recorder.constraintDestroyCount == 1)
        #expect(recorder.regionDestroyCount == 1)
    }

    @Test
    func mismatchedConstraintEventDoesNotDestroyManagedConstraint() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(112)
        let seatID = SeatID(rawValue: 15)
        let id = PointerConstraintID(rawValue: 4, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(112), kind: .locked)
        let mismatchedRawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(112),
            kind: .confined
        )
        let recorder = PointerConstraintDestroyRecorder(id: id, rawIdentity: rawIdentity)

        runtime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: recorder.managedConstraint(),
            lifetime: .oneShot
        )

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: RawSeatID(seatID),
                    event: .confined(mismatchedRawIdentity, surfaceID: surfaceID)
                )
            ) == nil
        )
        #expect(recorder.constraintDestroyCount == 0)
        #expect(recorder.regionDestroyCount == 0)
        #expect(runtime.lifecycle(for: id) == .requested)
        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try runtime.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func stalePointerConstraintIDDoesNotDestroyNewConstraintWhenRawIDIsReused() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(113)
        let seatID = SeatID(rawValue: 16)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(700), kind: .locked)
        let staleID = PointerConstraintID(rawValue: 5, kind: .locked)
        let replacementID = PointerConstraintID(rawValue: 6, kind: .locked)
        let staleRecorder = PointerConstraintDestroyRecorder(
            id: staleID,
            rawIdentity: rawIdentity
        )
        let replacementRecorder = PointerConstraintDestroyRecorder(
            id: replacementID,
            rawIdentity: rawIdentity
        )

        runtime.insert(
            id: staleID,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: staleRecorder.managedConstraint(),
            lifetime: .persistent
        )
        try runtime.destroyPointerConstraint(staleID)
        #expect(staleRecorder.constraintDestroyCount == 1)

        runtime.insert(
            id: replacementID,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: replacementRecorder.managedConstraint(),
            lifetime: .persistent
        )

        #expect(throws: PointerCaptureError.unknownPointerConstraint(staleID)) {
            try runtime.destroyPointerConstraint(staleID)
        }
        #expect(replacementRecorder.constraintDestroyCount == 0)

        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: RawSeatID(seatID),
                    event: .locked(rawIdentity, surfaceID: surfaceID)
                )
            ) == .activated(replacementID)
        )

        try runtime.destroyPointerConstraint(replacementID)
        #expect(replacementRecorder.constraintDestroyCount == 1)
    }
}

private final class PointerConstraintDestroyRecorder {
    private let id: PointerConstraintID
    private let rawIdentity: RawPointerConstraintIdentity

    var constraintDestroyCount = 0
    var regionDestroyCount = 0

    init(
        id constraintID: PointerConstraintID,
        rawIdentity constraintRawIdentity: RawPointerConstraintIdentity
    ) {
        id = constraintID
        rawIdentity = constraintRawIdentity
    }

    func managedConstraint() -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: id, rawIdentity: rawIdentity) { [self] in
            constraintDestroyCount += 1
            regionDestroyCount += 1
        }
    }
}
