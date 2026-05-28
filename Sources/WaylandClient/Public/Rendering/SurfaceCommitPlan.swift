package enum SurfaceDamageExtent: Equatable, Sendable {
    case buffer([BufferDamageRectangle])
    case logical([LogicalRect])
}

package enum ViewportCommitMode: Equatable, Sendable {
    case omitDestination
    case useLogicalSizeAsDestination

    package func destination(for geometry: SurfaceGeometry) -> PositiveLogicalSize? {
        switch self {
        case .omitDestination:
            nil
        case .useLogicalSizeAsDestination:
            geometry.logicalSize
        }
    }
}

package enum DamageCoordinateMode: Equatable, Sendable {
    case buffer
    case logical

    package func extent(
        for geometry: SurfaceGeometry,
        damage: SurfaceDamageRegion?
    ) throws -> SurfaceDamageExtent {
        switch self {
        case .buffer:
            if let damage {
                return try SurfaceDamageExtent.buffer(damage.bufferRectangles(for: geometry))
            }
            return .buffer([
                BufferDamageRectangle(
                    x: 0,
                    y: 0,
                    width: geometry.bufferSize.width.rawValue,
                    height: geometry.bufferSize.height.rawValue
                )
            ])
        case .logical:
            if let damage {
                try damage.validate(within: geometry)
                return .logical(damage.rectangles)
            }
            return .logical([
                LogicalRect(
                    origin: .zero,
                    size: geometry.logicalSize
                )
            ])
        }
    }
}

package struct SurfaceCommitPlan: Equatable, Sendable {
    package let geometry: SurfaceGeometry
    package let bufferScale: Int32
    package let viewportMode: ViewportCommitMode
    package let viewportDestination: PositiveLogicalSize?
    package let damageMode: DamageCoordinateMode
    package let damage: SurfaceDamageExtent

    package init(
        geometry surfaceGeometry: SurfaceGeometry,
        bufferScale planBufferScale: Int32,
        viewportMode: ViewportCommitMode,
        damageMode: DamageCoordinateMode,
        damage explicitDamage: SurfaceDamageRegion? = nil
    ) throws {
        geometry = surfaceGeometry
        bufferScale = planBufferScale
        self.viewportMode = viewportMode
        viewportDestination = viewportMode.destination(for: surfaceGeometry)
        self.damageMode = damageMode
        damage = try damageMode.extent(for: surfaceGeometry, damage: explicitDamage)
    }
}
