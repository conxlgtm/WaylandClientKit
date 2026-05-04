package enum SurfaceDamageExtent: Equatable, Sendable {
    case buffer(width: Int32, height: Int32)
    case logical(width: Int32, height: Int32)
}

package struct SurfaceCommitPlan: Equatable, Sendable {
    package let bufferScale: Int32
    package let viewportDestination: PositiveTopLevelSize?
    package let damage: SurfaceDamageExtent

    package init(
        geometry: SurfaceGeometry,
        bufferScale planBufferScale: Int32,
        usesViewportDestination: Bool,
        usesBufferDamage: Bool
    ) {
        bufferScale = planBufferScale
        viewportDestination = usesViewportDestination ? geometry.logicalSize : nil
        damage =
            if usesBufferDamage {
                .buffer(
                    width: geometry.bufferSize.width.rawValue,
                    height: geometry.bufferSize.height.rawValue
                )
            } else {
                .logical(
                    width: geometry.logicalSize.width.rawValue,
                    height: geometry.logicalSize.height.rawValue
                )
            }
    }
}
