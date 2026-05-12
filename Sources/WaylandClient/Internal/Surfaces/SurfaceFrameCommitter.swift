import WaylandRaw

enum SurfaceFrameCommitter {
    static func requestFrameCallback<RoleResources>(
        on surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>,
        generation: UInt64,
        onFrame: @escaping () -> Void
    ) throws -> FrameCallbackRegistration {
        try runtime.requestFrameCallback(generation: generation)
        do {
            return try surface.requestFrame(onDone: onFrame)
        } catch {
            runtime.cancelFrameCallback()
            throw error
        }
    }

    @discardableResult
    static func commit<RoleResources>(
        buffer: RawBuffer,
        to surface: RawSurface,
        scaleInstallation: SurfaceScaleInstallation,
        runtime: inout SurfaceRuntime<RoleResources>,
        generation: UInt64,
        geometry: SurfaceGeometry
    ) throws -> SurfaceCommitPlan {
        let damageMode: DamageCoordinateMode = surface.usesBufferDamage ? .buffer : .logical
        let plan = scaleInstallation.commitPlan(
            geometry: geometry,
            damageMode: damageMode
        )

        surface.setBufferScale(plan.bufferScale)
        scaleInstallation.applyViewportDestinationIfNeeded(plan.viewportDestination)
        surface.attach(buffer: buffer)
        apply(plan.damage, to: surface)
        surface.commit()
        try runtime.recordCommittedFrame(generation: generation, plan: plan)
        return plan
    }

    private static func apply(_ damage: SurfaceDamageExtent, to surface: RawSurface) {
        switch damage {
        case .buffer(let width, let height):
            surface.damageFullBuffer(width: width, height: height)
        case .logical(let width, let height):
            surface.damageFullLogical(width: width, height: height)
        }
    }
}
