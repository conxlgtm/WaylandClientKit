import Testing

@testable import WaylandClient

@Suite
struct SurfaceGeometryTests {
    @Test
    func surfaceScaleComputesBufferSizeWithHalfAwayFromZeroRounding() throws {
        let cases: [(PositiveTopLevelSize, SurfaceScale, PositivePixelSize)] = [
            (
                try PositiveTopLevelSize(width: 100, height: 50),
                .one,
                try PositivePixelSize(width: 100, height: 50)
            ),
            (
                try PositiveTopLevelSize(width: 100, height: 50),
                try SurfaceScale(numerator: 180, denominator: 120),
                try PositivePixelSize(width: 150, height: 75)
            ),
            (
                try PositiveTopLevelSize(width: 101, height: 51),
                try SurfaceScale(numerator: 180, denominator: 120),
                try PositivePixelSize(width: 152, height: 77)
            ),
            (
                try PositiveTopLevelSize(width: 1, height: 1),
                try SurfaceScale(numerator: 150, denominator: 120),
                try PositivePixelSize(width: 1, height: 1)
            ),
        ]

        for (logicalSize, scale, expectedBufferSize) in cases {
            let geometry = SurfaceGeometry(logicalSize: logicalSize, scale: scale)

            #expect(geometry.logicalSize == logicalSize)
            #expect(geometry.scale == scale)
            #expect(geometry.bufferSize == expectedBufferSize)
        }
    }

    @Test
    func surfaceScaleRejectsInvalidRationalValues() {
        #expect(
            throws: ClientError.invalidWindowConfiguration(
                .nonPositiveScaleNumerator(0)
            )
        ) {
            _ = try SurfaceScale(numerator: 0, denominator: 120)
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(.zeroScaleDenominator)
        ) {
            _ = try SurfaceScale(numerator: 120, denominator: 0)
        }
    }
}
