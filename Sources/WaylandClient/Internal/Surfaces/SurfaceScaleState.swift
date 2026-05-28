package enum SurfaceScaleCapability: Equatable, Sendable {
    case integerOnly
    case fractional
}

package struct SurfaceScaleState: Equatable, Sendable {
    private enum Mode: Equatable, Sendable {
        case integerOnly(preferred: SurfaceScale)
        case fractionalCapable(integerFallback: SurfaceScale, fractional: SurfaceScale?)
    }

    private var mode: Mode

    package init(capability: SurfaceScaleCapability = .integerOnly) {
        switch capability {
        case .fractional:
            mode = .fractionalCapable(integerFallback: .one, fractional: nil)
        case .integerOnly:
            mode = .integerOnly(preferred: .one)
        }
    }

    package var capability: SurfaceScaleCapability {
        switch mode {
        case .integerOnly:
            .integerOnly
        case .fractionalCapable:
            .fractional
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
        logicalSize: PositiveLogicalSize
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
        logicalSize: PositiveLogicalSize
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

    package func geometry(logicalSize: PositiveLogicalSize) throws -> SurfaceGeometry {
        try SurfaceGeometry(logicalSize: logicalSize, scale: effectiveScale)
    }

    package func commitPlan(
        geometry: SurfaceGeometry,
        damageMode: DamageCoordinateMode,
        damage: SurfaceDamageRegion? = nil
    ) throws -> SurfaceCommitPlan {
        try SurfaceCommitPlan(
            geometry: geometry,
            bufferScale: bufferScaleForCommit,
            viewportMode: viewportCommitMode,
            damageMode: damageMode,
            damage: damage
        )
    }

    package var viewportCommitMode: ViewportCommitMode {
        requiresViewportDestination ? .useLogicalSizeAsDestination : .omitDestination
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
