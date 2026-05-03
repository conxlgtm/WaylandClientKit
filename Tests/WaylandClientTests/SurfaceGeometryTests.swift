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

        #expect(
            throws: ClientError.invalidWindowConfiguration(
                .scaleNumeratorTooLarge(UInt32(Int32.max) + 1)
            )
        ) {
            _ = try SurfaceScale(numerator: UInt32(Int32.max) + 1, denominator: 1)
        }
    }

    @Test
    func surfaceScaleStateUsesIntegerScaleUntilFractionalScaleArrives() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)

        #expect(scaleState.effectiveScale == .one)
        #expect(try scaleState.updatePreferredBufferScale(2))
        #expect(
            scaleState.geometry(logicalSize: try PositiveTopLevelSize(width: 80, height: 60))
                .bufferSize
                == (try PositivePixelSize(width: 160, height: 120))
        )
        #expect(!scaleState.requiresViewportDestination)
        #expect(scaleState.bufferScaleForCommit == 2)

        #expect(try scaleState.updatePreferredFractionalScale(180))
        #expect(
            scaleState.geometry(logicalSize: try PositiveTopLevelSize(width: 80, height: 60))
                .bufferSize
                == (try PositivePixelSize(width: 120, height: 90))
        )
        #expect(scaleState.requiresViewportDestination)
        #expect(scaleState.bufferScaleForCommit == 1)

        let integerScaleChanged = try scaleState.updatePreferredBufferScale(3)
        #expect(!integerScaleChanged)
        #expect(
            scaleState.geometry(logicalSize: try PositiveTopLevelSize(width: 80, height: 60))
                .bufferSize
                == (try PositivePixelSize(width: 120, height: 90))
        )
    }

    @Test
    func surfaceScaleStateRejectsInvalidPreferredScales() {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)

        #expect(
            throws: WindowError.invalidConfigure(.invalidPreferredBufferScale(0))
        ) {
            _ = try scaleState.updatePreferredBufferScale(0)
        }

        #expect(throws: WindowError.invalidConfigure(.invalidFractionalScale(0))) {
            _ = try scaleState.updatePreferredFractionalScale(0)
        }
    }
}
