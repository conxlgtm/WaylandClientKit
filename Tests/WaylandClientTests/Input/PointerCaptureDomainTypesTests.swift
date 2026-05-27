import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerCaptureDomainTypesTests {
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
