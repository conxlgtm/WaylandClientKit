import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerCaptureDomainTypesTests {  // swiftlint:disable:this type_body_length
    @Test
    func emptyConstraintRegionIsRejected() {
        #expect(throws: PointerCaptureError.emptyRegion) {
            _ = try PointerConstraintRegion([])
        }
    }

    @Test
    func constraintRegionStoresRectangles() throws {
        let rect = try LogicalRect(x: 4, y: 5, width: 32, height: 48)
        let region = try PointerConstraintRegion([rect])

        #expect(region.rectangles == [rect])
    }

    @Test
    func relativePointerMotionPreservesMicrosecondTimeAndDeltas() {
        let event = RelativePointerMotionEvent(
            time: WaylandTimestampMicroseconds(rawValue: 123_456),
            delta: PointerDelta(dx: 1.5, dy: -2.0),
            unacceleratedDelta: PointerDelta(dx: 1.0, dy: -1.5)
        )

        #expect(event.time.rawValue == 123_456)
        #expect(event.delta == PointerDelta(dx: 1.5, dy: -2.0))
        #expect(event.unacceleratedDelta == PointerDelta(dx: 1.0, dy: -1.5))
    }

    @Test
    func pointerConstraintIDDescriptionIncludesKind() {
        #expect(
            PointerConstraintID(rawValue: 7, kind: .locked).description
                == "locked-pointer-7"
        )
        #expect(
            PointerConstraintID(rawValue: 8, kind: .confined).description
                == "confined-pointer-8"
        )
    }

    @Test
    func relativePointerRegistryRejectsDuplicateSeatSubscription() throws {
        var registry = RelativePointerSubscriptionRegistry()
        let seatID = SeatID(rawValue: 9)

        try registry.preflight(seatID: seatID)
        registry.insert(id: RelativePointerSubscriptionID(rawValue: 1), seatID: seatID)

        #expect(
            throws: PointerCaptureError.relativePointerAlreadySubscribed(seatID: seatID)
        ) {
            try registry.preflight(seatID: seatID)
        }
    }

    @Test
    func relativePointerRegistryAllowsSubscriptionAfterRemoval() throws {
        var registry = RelativePointerSubscriptionRegistry()
        let seatID = SeatID(rawValue: 10)
        let id = RelativePointerSubscriptionID(rawValue: 2)

        registry.insert(id: id, seatID: seatID)
        #expect(registry.remove(id) == seatID)

        try registry.preflight(seatID: seatID)
    }

    @Test
    func relativePointerRegistryAllowsSubscriptionAfterRemoveAll() throws {
        var registry = RelativePointerSubscriptionRegistry()
        let seatID = SeatID(rawValue: 11)

        registry.insert(id: RelativePointerSubscriptionID(rawValue: 3), seatID: seatID)
        registry.removeAll()

        try registry.preflight(seatID: seatID)
    }

    @Test
    func pointerConstraintRegistryRejectsDuplicateLockForSurfaceAndSeat() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(100)
        let seatID = SeatID(rawValue: 1)

        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        registry.insert(
            id: PointerConstraintID(rawValue: 1, kind: .locked),
            surfaceID: surfaceID,
            seatID: seatID,
            lifetime: .oneShot
        )

        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func pointerConstraintRegistryRejectsConfineAfterLock() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(101)
        let seatID = SeatID(rawValue: 2)

        registry.insert(
            id: PointerConstraintID(rawValue: 2, kind: .locked),
            surfaceID: surfaceID,
            seatID: seatID,
            lifetime: .oneShot
        )

        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func pointerConstraintRegistryRejectsLockAfterConfine() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(102)
        let seatID = SeatID(rawValue: 3)

        registry.insert(
            id: PointerConstraintID(rawValue: 3, kind: .confined),
            surfaceID: surfaceID,
            seatID: seatID,
            lifetime: .oneShot
        )

        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func pointerConstraintRegistryAllowsConstraintAfterRemoval() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(103)
        let seatID = SeatID(rawValue: 4)
        let id = PointerConstraintID(rawValue: 4, kind: .confined)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .oneShot)
        _ = registry.remove(id)

        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    @Test
    func oneShotLockUnlockedRemovesConstraintAndAllowsRelock() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(104)
        let seatID = SeatID(rawValue: 5)
        let id = PointerConstraintID(rawValue: 5, kind: .locked)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .oneShot)
        #expect(registry.transition(.locked(id)) == .activated(id))
        #expect(registry.transition(.unlocked(id)) == .defunctOneShot(id))
        #expect(registry.lifecycle(for: id) == nil)

        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    @Test
    func oneShotConfineUnconfinedRemovesConstraintAndAllowsReconfinement() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(105)
        let seatID = SeatID(rawValue: 6)
        let id = PointerConstraintID(rawValue: 6, kind: .confined)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .oneShot)
        #expect(registry.transition(.confined(id)) == .activated(id))
        #expect(registry.transition(.unconfined(id)) == .defunctOneShot(id))
        #expect(registry.lifecycle(for: id) == nil)

        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    @Test
    func persistentLockUnlockedKeepsConstraintAndRejectsSecondConstraint() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(106)
        let seatID = SeatID(rawValue: 7)
        let id = PointerConstraintID(rawValue: 7, kind: .locked)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .persistent)
        #expect(registry.transition(.locked(id)) == .activated(id))
        #expect(registry.transition(.unlocked(id)) == .inactivePersistent(id))
        #expect(registry.lifecycle(for: id) == .inactivePersistent)
        #expect(registry.transition(.locked(id)) == .activated(id))
        #expect(registry.lifecycle(for: id) == .active)

        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func duplicateConstraintRejectedOnlyBeforeOneShotTerminalEvent() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(107)
        let seatID = SeatID(rawValue: 8)
        let id = PointerConstraintID(rawValue: 8, kind: .locked)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .oneShot)
        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
        #expect(registry.transition(.unlocked(id)) == .defunctOneShot(id))

        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    @Test
    func outOfOrderConstraintEventDoesNotCorruptRegistry() throws {
        var registry = PointerConstraintRegistry()
        let surfaceID = RawObjectID(108)
        let seatID = SeatID(rawValue: 9)
        let id = PointerConstraintID(rawValue: 9, kind: .locked)
        let mismatchedID = PointerConstraintID(rawValue: 9, kind: .confined)

        registry.insert(id: id, surfaceID: surfaceID, seatID: seatID, lifetime: .oneShot)
        #expect(registry.transition(.confined(mismatchedID)) == .ignored)
        #expect(registry.lifecycle(for: id) == .requested)

        #expect(throws: PointerCaptureError.alreadyConstrained(seatID: seatID)) {
            try registry.preflight(surfaceID: surfaceID, seatID: seatID)
        }
    }

    @Test
    func oneShotUnlockedPublishesDefunctAndDestroysManagedConstraintAndRegion() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(109)
        let seatID = SeatID(rawValue: 12)
        let rawSeatID = RawSeatID(seatID)
        let id = PointerConstraintID(rawValue: 109, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(109), kind: .locked)
        let recorder = PointerConstraintDestroyRecorder(id: id)

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
        let id = PointerConstraintID(rawValue: 110, kind: .confined)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(110), kind: .confined)
        let recorder = PointerConstraintDestroyRecorder(id: id)

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
        let id = PointerConstraintID(rawValue: 111, kind: .locked)
        let rawIdentity = RawPointerConstraintIdentity(objectID: RawObjectID(111), kind: .locked)
        let recorder = PointerConstraintDestroyRecorder(id: id)

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

        try runtime.destroyPointerConstraint(id)
        #expect(recorder.constraintDestroyCount == 1)
        #expect(recorder.regionDestroyCount == 1)
    }

    @Test
    func mismatchedConstraintEventDoesNotDestroyManagedConstraint() throws {
        var runtime = PointerConstraintRuntime()
        let surfaceID = RawObjectID(112)
        let seatID = SeatID(rawValue: 15)
        let id = PointerConstraintID(rawValue: 112, kind: .locked)
        let mismatchedRawIdentity = RawPointerConstraintIdentity(
            objectID: RawObjectID(112),
            kind: .confined
        )
        let recorder = PointerConstraintDestroyRecorder(id: id)

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

    #if DEBUG
        @Test
        func pointerlessSeatReportsPointerCaptureError() throws {
            let seatID = SeatID(rawValue: 41)
            let seat = try RawSeat.testingNoopSeatForRequestRecording(
                id: RawSeatID(seatID),
                pointerAddress: 0x5EA7
            )

            #expect(throws: PointerCaptureError.pointerUnavailable(seatID)) {
                try PointerCaptureManager.requirePointerDevice(on: seat, seatID: seatID)
            }
        }
    #endif

    @Test
    func fixedPointerLocationRejectsInvalidCoordinates() {
        let nanError = pointerCaptureError {
            _ = try FixedPointerLocation(PointerLocation(x: .nan, y: 1))
        }
        guard case .invalidCursorHint(let nanLocation) = nanError else {
            Issue.record("expected invalid cursor hint for NaN coordinate")
            return
        }
        #expect(nanLocation.x.isNaN)
        #expect(nanLocation.y == 1)

        #expect(
            throws: PointerCaptureError.invalidCursorHint(
                PointerLocation(x: 1, y: .infinity)
            )
        ) {
            _ = try FixedPointerLocation(PointerLocation(x: 1, y: .infinity))
        }
        #expect(
            throws: PointerCaptureError.invalidCursorHint(
                PointerLocation(x: Double(Int32.max), y: 0)
            )
        ) {
            _ = try FixedPointerLocation(PointerLocation(x: Double(Int32.max), y: 0))
        }
    }

    @Test
    func fixedPointerLocationConvertsCoordinatesToWaylandFixed() throws {
        let location = try FixedPointerLocation(PointerLocation(x: 1.5, y: -0.5))

        #expect(location.x == WaylandFixed(rawValue: 384))
        #expect(location.y == WaylandFixed(rawValue: -128))
    }
}

private final class PointerConstraintDestroyRecorder {
    private let id: PointerConstraintID

    var constraintDestroyCount = 0
    var regionDestroyCount = 0

    init(id constraintID: PointerConstraintID) {
        id = constraintID
    }

    func managedConstraint() -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: id) { [self] in
            constraintDestroyCount += 1
            regionDestroyCount += 1
        }
    }
}

private func pointerCaptureError(_ body: () throws -> Void) -> PointerCaptureError? {
    do {
        try body()
    } catch let error as PointerCaptureError {
        return error
    } catch {
        Issue.record("unexpected error: \(error)")
    }
    return nil
}
