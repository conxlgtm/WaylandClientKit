package struct SurfaceScaleState: Equatable, Sendable {
    private var preferredIntegerScale = SurfaceScale.one
    private var preferredFractionalScale: SurfaceScale?
    private let usesFractionalScale: Bool

    package init(usesFractionalScale shouldUseFractionalScale: Bool = false) {
        usesFractionalScale = shouldUseFractionalScale
    }

    package var effectiveScale: SurfaceScale {
        if usesFractionalScale, let preferredFractionalScale {
            return preferredFractionalScale
        }

        return preferredIntegerScale
    }

    package mutating func updatePreferredBufferScale(_ factor: Int32) throws -> Bool {
        guard factor > 0 else {
            throw WindowError.invalidConfigure(.invalidPreferredBufferScale(factor))
        }

        let previousScale = effectiveScale
        preferredIntegerScale = SurfaceScale(
            uncheckedNumerator: UInt32(factor),
            denominator: 1
        )
        return effectiveScale != previousScale
    }

    package mutating func updatePreferredFractionalScale(_ scale: UInt32) throws -> Bool {
        guard scale > 0 else {
            throw WindowError.invalidConfigure(.invalidFractionalScale(scale))
        }

        guard scale <= UInt32(Int32.max) else {
            throw WindowError.invalidConfigure(.invalidFractionalScale(scale))
        }

        let previousScale = effectiveScale
        preferredFractionalScale = SurfaceScale(
            uncheckedNumerator: scale,
            denominator: SurfaceScale.fractionalScaleDenominator
        )
        return effectiveScale != previousScale
    }

    package func geometry(logicalSize: PositiveTopLevelSize) -> SurfaceGeometry {
        SurfaceGeometry(logicalSize: logicalSize, scale: effectiveScale)
    }

    package var requiresViewportDestination: Bool {
        usesFractionalScale && preferredFractionalScale != nil
    }

    package var bufferScaleForCommit: Int32 {
        guard !requiresViewportDestination, let integerValue = effectiveScale.integerValue else {
            return 1
        }

        return integerValue
    }
}
