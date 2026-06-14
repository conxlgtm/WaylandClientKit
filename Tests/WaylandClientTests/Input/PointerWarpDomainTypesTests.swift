import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerWarpDomainTypesTests {
    @Test
    func fixedPointerWarpPositionRejectsNegativeCoordinates() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = LogicalOffset(x: -1, y: 0)

        #expect(
            throws: PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        ) {
            _ = try FixedPointerWarpPosition(position: position, windowSize: windowSize)
        }
    }

    @Test
    func fixedPointerWarpPositionRejectsCoordinatesOutsideWindow() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = LogicalOffset(x: 10, y: 19)

        #expect(
            throws: PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        ) {
            _ = try FixedPointerWarpPosition(position: position, windowSize: windowSize)
        }
    }

    @Test
    func fixedPointerWarpPositionConvertsLogicalCoordinatesToWaylandFixed() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = try FixedPointerWarpPosition(
            position: LogicalOffset(x: 3, y: 4),
            windowSize: windowSize
        )

        #expect(position.x == WaylandFixed(rawValue: 768))
        #expect(position.y == WaylandFixed(rawValue: 1_024))
    }
}
