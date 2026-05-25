import Testing

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
}
