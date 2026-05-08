package enum SurfaceDamageExtent: Equatable, Sendable {
    case buffer(width: Int32, height: Int32)
    case logical(width: Int32, height: Int32)
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

    package func extent(for geometry: SurfaceGeometry) -> SurfaceDamageExtent {
        switch self {
        case .buffer:
            .buffer(
                width: geometry.bufferSize.width.rawValue,
                height: geometry.bufferSize.height.rawValue
            )
        case .logical:
            .logical(
                width: geometry.logicalSize.width.rawValue,
                height: geometry.logicalSize.height.rawValue
            )
        }
    }
}

package struct SurfaceCommitPlan: Equatable, Sendable {
    package let bufferScale: Int32
    package let viewportDestination: PositiveLogicalSize?
    package let damage: SurfaceDamageExtent

    package init(
        geometry: SurfaceGeometry,
        bufferScale planBufferScale: Int32,
        viewportMode: ViewportCommitMode,
        damageMode: DamageCoordinateMode
    ) {
        bufferScale = planBufferScale
        viewportDestination = viewportMode.destination(for: geometry)
        damage = damageMode.extent(for: geometry)
    }
}
