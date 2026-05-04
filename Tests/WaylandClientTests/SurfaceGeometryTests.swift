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
            let geometry = try SurfaceGeometry(logicalSize: logicalSize, scale: scale)

            #expect(geometry.logicalSize == logicalSize)
            #expect(geometry.scale == scale)
            #expect(geometry.bufferSize == expectedBufferSize)
        }
    }

    @Test
    func tinyFractionalScaleProducesMinimumPositiveBufferSize() throws {
        let geometry = try SurfaceGeometry(
            logicalSize: PositiveTopLevelSize(width: 1, height: 1),
            scale: SurfaceScale(numerator: 1, denominator: 120)
        )

        #expect(geometry.bufferSize == (try PositivePixelSize(width: 1, height: 1)))
    }

    @Test
    func surfaceScaleBufferSizeOverflowThrowsTypedError() throws {
        let logicalSize = try PositiveTopLevelSize(width: 640, height: 480)
        let scale = try SurfaceScale(numerator: UInt32(Int32.max), denominator: 1)

        #expect(
            throws: WindowError.invalidConfigure(
                .unrepresentableSurfaceBufferSize(
                    logicalDimension: 640,
                    scaleNumerator: UInt32(Int32.max),
                    scaleDenominator: 1
                )
            )
        ) {
            _ = try SurfaceGeometry(logicalSize: logicalSize, scale: scale)
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
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)

        #expect(scaleState.effectiveScale == .one)
        #expect(try scaleState.updatePreferredBufferScale(2, logicalSize: logicalSize))
        #expect(
            try scaleState.geometry(logicalSize: logicalSize)
                .bufferSize
                == (try PositivePixelSize(width: 160, height: 120))
        )
        #expect(!scaleState.requiresViewportDestination)
        #expect(scaleState.bufferScaleForCommit == 2)

        #expect(try scaleState.updatePreferredFractionalScale(180, logicalSize: logicalSize))
        #expect(
            try scaleState.geometry(logicalSize: logicalSize)
                .bufferSize
                == (try PositivePixelSize(width: 120, height: 90))
        )
        #expect(scaleState.requiresViewportDestination)
        #expect(scaleState.bufferScaleForCommit == 1)

        let integerScaleChanged = try scaleState.updatePreferredBufferScale(
            3,
            logicalSize: logicalSize
        )
        #expect(!integerScaleChanged)
        #expect(
            try scaleState.geometry(logicalSize: logicalSize)
                .bufferSize
                == (try PositivePixelSize(width: 120, height: 90))
        )
    }

    @Test
    func surfaceScaleStateRejectsFractionalUpdateWhenFractionalScalingIsDisabled() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: false)
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)

        #expect(throws: WindowError.invalidConfigure(.invalidFractionalScale(180))) {
            _ = try scaleState.updatePreferredFractionalScale(180, logicalSize: logicalSize)
        }
        #expect(scaleState.effectiveScale == .one)
    }

    @Test
    func bufferScaleForCommitUsesIntegerScaleUntilFractionalScaleArrives() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)

        #expect(try scaleState.updatePreferredBufferScale(2, logicalSize: logicalSize))

        #expect(scaleState.bufferScaleForCommit == 2)
        #expect(!scaleState.requiresViewportDestination)
    }

    @Test
    func integerScaleCommitPlanUsesIntegerBufferScaleWithoutViewport() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)

        #expect(try scaleState.updatePreferredBufferScale(2, logicalSize: logicalSize))
        let geometry = try scaleState.geometry(logicalSize: logicalSize)
        let plan = scaleState.commitPlan(
            geometry: geometry,
            surfaceUsesBufferDamage: true
        )

        #expect(geometry.bufferSize == (try PositivePixelSize(width: 160, height: 120)))
        #expect(plan.bufferScale == 2)
        #expect(plan.viewportDestination == nil)
        #expect(plan.damage == .buffer(width: 160, height: 120))
    }

    @Test
    func fractionalScaleCommitPlanUsesViewportDestinationAndBufferScaleOne() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)
        let logicalSize = try PositiveTopLevelSize(width: 101, height: 51)

        #expect(try scaleState.updatePreferredFractionalScale(180, logicalSize: logicalSize))
        let geometry = try scaleState.geometry(logicalSize: logicalSize)
        let plan = scaleState.commitPlan(
            geometry: geometry,
            surfaceUsesBufferDamage: true
        )

        #expect(geometry.bufferSize == (try PositivePixelSize(width: 152, height: 77)))
        #expect(plan.bufferScale == 1)
        #expect(plan.viewportDestination == logicalSize)
        #expect(plan.damage == .buffer(width: 152, height: 77))
    }

    @Test
    func surfaceCommitPlanUsesLogicalDamageWhenBufferDamageIsUnavailable() throws {
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)
        let geometry = try SurfaceGeometry(
            logicalSize: logicalSize,
            scale: SurfaceScale(numerator: 2, denominator: 1)
        )
        let plan = SurfaceCommitPlan(
            geometry: geometry,
            bufferScale: 2,
            usesViewportDestination: false,
            usesBufferDamage: false
        )

        #expect(plan.damage == .logical(width: 80, height: 60))
    }

    @Test
    func surfaceScaleStateRejectsInvalidPreferredScales() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: true)
        let logicalSize = try PositiveTopLevelSize(width: 80, height: 60)

        #expect(
            throws: WindowError.invalidConfigure(.invalidPreferredBufferScale(0))
        ) {
            _ = try scaleState.updatePreferredBufferScale(0, logicalSize: logicalSize)
        }

        #expect(throws: WindowError.invalidConfigure(.invalidFractionalScale(0))) {
            _ = try scaleState.updatePreferredFractionalScale(0, logicalSize: logicalSize)
        }
    }

    @Test
    func preferredBufferScaleTooLargeThrowsTypedError() throws {
        var scaleState = SurfaceScaleState(usesFractionalScale: false)
        let logicalSize = try PositiveTopLevelSize(width: 640, height: 480)

        #expect(
            throws: WindowError.invalidConfigure(
                .unrepresentableSurfaceBufferSize(
                    logicalDimension: 640,
                    scaleNumerator: UInt32(Int32.max),
                    scaleDenominator: 1
                )
            )
        ) {
            _ = try scaleState.updatePreferredBufferScale(
                Int32.max,
                logicalSize: logicalSize
            )
        }
    }
}
