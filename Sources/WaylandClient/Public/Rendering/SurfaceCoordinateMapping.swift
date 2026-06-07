/// A point in buffer-pixel coordinate space.
///
/// Values describe positions in the scaled buffer plane. Edge coordinates such as
/// `x == bufferSize.width` or `y == bufferSize.height` can result from geometry conversion.
/// Callers that index pixels must clamp or reject those edge values first.
public struct BufferPixelPoint: Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x pointX: Int, y pointY: Int) {
        x = pointX
        y = pointY
    }
}

extension SoftwareFrameGeometry {
    public func bufferPixelPoint(logicalX: Double, logicalY: Double) -> BufferPixelPoint {
        BufferPixelPoint(
            x: Self.bufferCoordinate(
                logicalCoordinate: logicalX,
                logicalDimension: logicalSize.width.rawValue,
                bufferDimension: bufferSize.width.rawValue
            ),
            y: Self.bufferCoordinate(
                logicalCoordinate: logicalY,
                logicalDimension: logicalSize.height.rawValue,
                bufferDimension: bufferSize.height.rawValue
            )
        )
    }

    private static func bufferCoordinate(
        logicalCoordinate: Double,
        logicalDimension: Int32,
        bufferDimension: Int32
    ) -> Int {
        let scale = Double(bufferDimension) / Double(logicalDimension)
        return Int((logicalCoordinate * scale).rounded(.toNearestOrAwayFromZero))
    }
}
