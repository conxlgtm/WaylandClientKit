import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerConstraintRemovalTests {
    @Test
    func removingSeatDestroysOnlyItsConstraintsAndClearsItsKeys() throws {
        var runtime = PointerConstraintRuntime()
        let removedSeatID = SeatID(rawValue: 17)
        let retainedSeatID = SeatID(rawValue: 18)
        let removedSurfaceID = RawObjectID(114)
        let retainedSurfaceID = RawObjectID(115)
        let removedID = PointerConstraintID(rawValue: 7, kind: .locked)
        let retainedID = PointerConstraintID(rawValue: 8, kind: .confined)
        let removedRecorder = PointerConstraintRemovalRecorder(
            id: removedID,
            rawIdentity: .init(objectID: RawObjectID(701), kind: .locked)
        )
        let retainedRecorder = PointerConstraintRemovalRecorder(
            id: retainedID,
            rawIdentity: .init(objectID: RawObjectID(702), kind: .confined)
        )

        runtime.insert(
            id: removedID,
            seatID: removedSeatID,
            surfaceID: removedSurfaceID,
            constraint: removedRecorder.managedConstraint(),
            lifetime: .persistent
        )
        runtime.insert(
            id: retainedID,
            seatID: retainedSeatID,
            surfaceID: retainedSurfaceID,
            constraint: retainedRecorder.managedConstraint(),
            lifetime: .persistent
        )

        runtime.removeSeat(removedSeatID)

        #expect(removedRecorder.destroyCount == 1)
        #expect(retainedRecorder.destroyCount == 0)
        #expect(runtime.lifecycle(for: removedID) == nil)
        #expect(runtime.lifecycle(for: retainedID) == .requested)
        try runtime.preflight(surfaceID: removedSurfaceID, seatID: removedSeatID)
        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: retainedSeatID)) {
            try runtime.preflight(surfaceID: retainedSurfaceID, seatID: retainedSeatID)
        }

        runtime.removeAll()
        #expect(retainedRecorder.destroyCount == 1)
    }

    @Test
    func removingSurfaceClearsRawIdentityAndDestroysConstraintOnce() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(116)
        let seatID = SeatID(rawValue: 19)
        let id = PointerConstraintID(rawValue: 9, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(703),
            kind: .locked
        )
        let recorder = PointerConstraintRemovalRecorder(id: id, rawIdentity: rawIdentity)

        runtime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: recorder.managedConstraint(),
            lifetime: .oneShot
        )
        runtime.removeSurface(surfaceID)

        #expect(recorder.destroyCount == 1)
        #expect(runtime.lifecycle(for: id) == nil)
        #expect(
            runtime.processRawInputEvent(
                rawPointerConstraintEvent(
                    sequence: 1,
                    seatID: RawSeatID(seatID),
                    event: .unlocked(rawIdentity, surfaceID: surfaceID)
                )
            ) == nil
        )
        runtime.removeSurface(surfaceID)
        #expect(recorder.destroyCount == 1)
        try runtime.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    @Test
    func removeAllClearsEveryIndexAndIsIdempotent() throws {
        var runtime = PointerConstraintRuntime()
        let firstSurfaceID = RawObjectID(117)
        let secondSurfaceID = RawObjectID(118)
        let firstSeatID = SeatID(rawValue: 20)
        let secondSeatID = SeatID(rawValue: 21)
        let firstID = PointerConstraintID(rawValue: 10, kind: .locked)
        let secondID = PointerConstraintID(rawValue: 11, kind: .confined)
        let firstRecorder = PointerConstraintRemovalRecorder(
            id: firstID,
            rawIdentity: .init(objectID: RawObjectID(704), kind: .locked)
        )
        let secondRecorder = PointerConstraintRemovalRecorder(
            id: secondID,
            rawIdentity: .init(objectID: RawObjectID(705), kind: .confined)
        )

        runtime.insert(
            id: firstID,
            seatID: firstSeatID,
            surfaceID: firstSurfaceID,
            constraint: firstRecorder.managedConstraint(),
            lifetime: .oneShot
        )
        runtime.insert(
            id: secondID,
            seatID: secondSeatID,
            surfaceID: secondSurfaceID,
            constraint: secondRecorder.managedConstraint(),
            lifetime: .persistent
        )

        runtime.removeAll()
        runtime.removeAll()

        #expect(firstRecorder.destroyCount == 1)
        #expect(secondRecorder.destroyCount == 1)
        #expect(runtime.lifecycle(for: firstID) == nil)
        #expect(runtime.lifecycle(for: secondID) == nil)
        try runtime.preflight(surfaceID: firstSurfaceID, seatID: firstSeatID)
        try runtime.preflight(surfaceID: secondSurfaceID, seatID: secondSeatID)
    }
}

private final class PointerConstraintRemovalRecorder {
    private let id: PointerConstraintID
    private let rawIdentity: RawPointerConstraintIdentity

    var destroyCount = 0

    init(id constraintID: PointerConstraintID, rawIdentity: RawPointerConstraintIdentity) {
        id = constraintID
        self.rawIdentity = rawIdentity
    }

    func managedConstraint() -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: id, rawIdentity: rawIdentity) { [self] in
            destroyCount += 1
        }
    }
}
