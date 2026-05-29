public enum SurfaceRegionError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyDamageRegion
    case damageRectangleOutOfBounds(LogicalRect)

    public var description: String {
        switch self {
        case .emptyDamageRegion:
            "damage region must contain at least one rectangle"
        case .damageRectangleOutOfBounds(let rectangle):
            "damage rectangle \(rectangle) is outside the surface bounds"
        }
    }
}

public struct SurfaceRegion: Equatable, Sendable {
    public let rectangles: [LogicalRect]

    public init(rectangles regionRectangles: [LogicalRect]) {
        rectangles = regionRectangles
    }

    public init(_ regionRectangles: [LogicalRect]) {
        self.init(rectangles: regionRectangles)
    }
}

public struct SurfaceDamageRegion: Equatable, Sendable {
    public let rectangles: [LogicalRect]

    public init(rectangles damageRectangles: [LogicalRect]) throws {
        guard !damageRectangles.isEmpty else {
            throw SurfaceRegionError.emptyDamageRegion
        }

        rectangles = damageRectangles
    }

    public init(_ damageRectangles: [LogicalRect]) throws {
        try self.init(rectangles: damageRectangles)
    }
}

package struct BufferDamageRectangle: Equatable, Sendable {
    package let x: Int32
    package let y: Int32
    package let width: Int32
    package let height: Int32
}

extension SurfaceDamageRegion {
    package func validate(within geometry: SurfaceGeometry) throws {
        _ = try clippedRectangles(within: geometry)
    }

    package func clippedRectangles(within geometry: SurfaceGeometry) throws -> [LogicalRect] {
        let width = Int64(geometry.logicalSize.width.rawValue)
        let height = Int64(geometry.logicalSize.height.rawValue)
        var clippedRectangles: [LogicalRect] = []

        for rectangle in rectangles {
            let x = Int64(rectangle.origin.x)
            let y = Int64(rectangle.origin.y)
            let rectWidth = Int64(rectangle.size.width.rawValue)
            let rectHeight = Int64(rectangle.size.height.rawValue)
            let clippedX = max(x, 0)
            let clippedY = max(y, 0)
            let clippedRight = min(x + rectWidth, width)
            let clippedBottom = min(y + rectHeight, height)

            guard clippedX < clippedRight, clippedY < clippedBottom else {
                throw SurfaceRegionError.damageRectangleOutOfBounds(rectangle)
            }

            clippedRectangles.append(
                LogicalRect(
                    origin: LogicalOffset(x: Int32(clippedX), y: Int32(clippedY)),
                    size: try PositiveLogicalSize(
                        width: Int32(clippedRight - clippedX),
                        height: Int32(clippedBottom - clippedY)
                    )
                )
            )
        }

        return clippedRectangles
    }

    package func bufferRectangles(for geometry: SurfaceGeometry) throws
        -> [BufferDamageRectangle]
    {
        try clippedRectangles(within: geometry).map { rectangle in
            let x = Self.floorScaledCoordinate(
                Int64(rectangle.origin.x),
                logicalDimension: Int64(geometry.logicalSize.width.rawValue),
                bufferDimension: Int64(geometry.bufferSize.width.rawValue)
            )
            let y = Self.floorScaledCoordinate(
                Int64(rectangle.origin.y),
                logicalDimension: Int64(geometry.logicalSize.height.rawValue),
                bufferDimension: Int64(geometry.bufferSize.height.rawValue)
            )
            let right = Self.ceilScaledCoordinate(
                Int64(rectangle.origin.x) + Int64(rectangle.size.width.rawValue),
                logicalDimension: Int64(geometry.logicalSize.width.rawValue),
                bufferDimension: Int64(geometry.bufferSize.width.rawValue)
            )
            let bottom = Self.ceilScaledCoordinate(
                Int64(rectangle.origin.y) + Int64(rectangle.size.height.rawValue),
                logicalDimension: Int64(geometry.logicalSize.height.rawValue),
                bufferDimension: Int64(geometry.bufferSize.height.rawValue)
            )

            return BufferDamageRectangle(
                x: Int32(x),
                y: Int32(y),
                width: Int32(right - x),
                height: Int32(bottom - y)
            )
        }
    }

    private static func floorScaledCoordinate(
        _ coordinate: Int64,
        logicalDimension: Int64,
        bufferDimension: Int64
    ) -> Int64 {
        coordinate * bufferDimension / logicalDimension
    }

    private static func ceilScaledCoordinate(
        _ coordinate: Int64,
        logicalDimension: Int64,
        bufferDimension: Int64
    ) -> Int64 {
        let scaled = coordinate * bufferDimension
        return (scaled + logicalDimension - 1) / logicalDimension
    }
}
