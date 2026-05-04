import Testing

@testable import WaylandClient

@Suite
struct SurfaceCoordinateMappingTests {
    @Test
    func softwareFrameGeometryMapsLogicalPointToScaleOneBufferPixels() throws {
        let frameGeometry = SoftwareFrameGeometry(
            surface: try SurfaceGeometry(
                logicalSize: PositiveTopLevelSize(width: 100, height: 50),
                scale: .one
            )
        )

        #expect(
            frameGeometry.bufferPixelPoint(logicalX: 25, logicalY: 12)
                == BufferPixelPoint(x: 25, y: 12)
        )
    }

    @Test
    func softwareFrameGeometryMapsLogicalPointToIntegerScaleBufferPixels() throws {
        let frameGeometry = SoftwareFrameGeometry(
            surface: try SurfaceGeometry(
                logicalSize: PositiveTopLevelSize(width: 100, height: 50),
                scale: SurfaceScale(numerator: 2, denominator: 1)
            )
        )

        #expect(
            frameGeometry.bufferPixelPoint(logicalX: 25, logicalY: 12)
                == BufferPixelPoint(x: 50, y: 24)
        )
    }

    @Test
    func softwareFrameGeometryMapsLogicalPointToFractionalScaleBufferPixels() throws {
        let frameGeometry = SoftwareFrameGeometry(
            surface: try SurfaceGeometry(
                logicalSize: PositiveTopLevelSize(width: 101, height: 51),
                scale: SurfaceScale(numerator: 180, denominator: 120)
            )
        )

        #expect(
            frameGeometry.bufferPixelPoint(logicalX: 50.5, logicalY: 25.5)
                == BufferPixelPoint(x: 76, y: 39)
        )
    }

    @Test
    func softwareFrameGeometryMapsLogicalBoundsToBufferBounds() throws {
        let frameGeometry = SoftwareFrameGeometry(
            surface: try SurfaceGeometry(
                logicalSize: PositiveTopLevelSize(width: 100, height: 50),
                scale: SurfaceScale(numerator: 2, denominator: 1)
            )
        )

        #expect(
            frameGeometry.bufferPixelPoint(logicalX: 0, logicalY: 0)
                == BufferPixelPoint(x: 0, y: 0)
        )
        #expect(
            frameGeometry.bufferPixelPoint(logicalX: 100, logicalY: 50)
                == BufferPixelPoint(x: 200, y: 100)
        )
    }
}
