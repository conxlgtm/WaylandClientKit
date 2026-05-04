package struct SurfaceScaleState: Equatable, Sendable {
    private enum Mode: Equatable, Sendable {
        case integerOnly(preferred: SurfaceScale)
        case fractionalCapable(integerFallback: SurfaceScale, fractional: SurfaceScale?)
    }

    private var mode: Mode

    package init(usesFractionalScale shouldUseFractionalScale: Bool = false) {
        if shouldUseFractionalScale {
            mode = .fractionalCapable(integerFallback: .one, fractional: nil)
        } else {
            mode = .integerOnly(preferred: .one)
        }
    }

    package var effectiveScale: SurfaceScale {
        switch mode {
        case .integerOnly(let preferred):
            preferred
        case .fractionalCapable(let integerFallback, let fractional):
            fractional ?? integerFallback
        }
    }

    package mutating func updatePreferredBufferScale(
        _ factor: Int32,
        logicalSize: PositiveTopLevelSize
    ) throws -> Bool {
        guard factor > 0 else {
            throw WindowError.invalidConfigure(.invalidPreferredBufferScale(factor))
        }

        let preferredScale = SurfaceScale(
            uncheckedNumerator: UInt32(factor),
            denominator: 1
        )
        _ = try preferredScale.bufferSize(for: logicalSize)

        let previousScale = effectiveScale
        switch mode {
        case .integerOnly:
            mode = .integerOnly(preferred: preferredScale)
        case .fractionalCapable(_, let fractional):
            mode = .fractionalCapable(
                integerFallback: preferredScale,
                fractional: fractional
            )
        }
        return effectiveScale != previousScale
    }

    package mutating func updatePreferredFractionalScale(
        _ scale: UInt32,
        logicalSize: PositiveTopLevelSize
    ) throws -> Bool {
        guard scale > 0 else {
            throw WindowError.invalidConfigure(.invalidFractionalScale(scale))
        }

        guard scale <= UInt32(Int32.max) else {
            throw WindowError.invalidConfigure(.invalidFractionalScale(scale))
        }

        guard case .fractionalCapable(let integerFallback, _) = mode else {
            throw WindowError.invalidConfigure(.invalidFractionalScale(scale))
        }

        let preferredScale = SurfaceScale(
            uncheckedNumerator: scale,
            denominator: SurfaceScale.fractionalScaleDenominator
        )
        _ = try preferredScale.bufferSize(for: logicalSize)

        let previousScale = effectiveScale
        mode = .fractionalCapable(
            integerFallback: integerFallback,
            fractional: preferredScale
        )
        return effectiveScale != previousScale
    }

    package func geometry(logicalSize: PositiveTopLevelSize) throws -> SurfaceGeometry {
        try SurfaceGeometry(logicalSize: logicalSize, scale: effectiveScale)
    }

    package func commitPlan(
        geometry: SurfaceGeometry,
        surfaceUsesBufferDamage: Bool
    ) -> SurfaceCommitPlan {
        SurfaceCommitPlan(
            geometry: geometry,
            bufferScale: bufferScaleForCommit,
            usesViewportDestination: requiresViewportDestination,
            usesBufferDamage: surfaceUsesBufferDamage
        )
    }

    package var requiresViewportDestination: Bool {
        switch mode {
        case .integerOnly, .fractionalCapable(_, nil):
            false
        case .fractionalCapable(_, .some):
            true
        }
    }

    package var bufferScaleForCommit: Int32 {
        guard !requiresViewportDestination, let integerValue = effectiveScale.integerValue else {
            return 1
        }

        return integerValue
    }
}
