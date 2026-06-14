import WaylandRaw

package struct FixedPointerWarpPosition: Equatable, Sendable {
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(position: LogicalOffset, windowSize: PositiveLogicalSize) throws {
        guard
            position.x >= 0,
            position.y >= 0,
            position.x < windowSize.width.rawValue,
            position.y < windowSize.height.rawValue
        else {
            throw PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        }

        x = try WaylandFixed(
            pointerWarpCoordinate: position.x,
            position: position,
            windowSize: windowSize
        )
        y = try WaylandFixed(
            pointerWarpCoordinate: position.y,
            position: position,
            windowSize: windowSize
        )
    }
}

extension WaylandFixed {
    package init(
        pointerWarpCoordinate coordinate: Int32,
        position: LogicalOffset,
        windowSize: PositiveLogicalSize
    ) throws {
        let scaled = Int64(coordinate) * 256
        guard scaled <= Int64(Int32.max) else {
            throw PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        }

        self.init(rawValue: Int32(scaled))
    }
}
