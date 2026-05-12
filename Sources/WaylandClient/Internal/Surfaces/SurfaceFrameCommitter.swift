import WaylandRaw

struct SurfaceFrameCommitRequest {
    let buffer: RawBuffer
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
}

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
        _ request: SurfaceFrameCommitRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
    ) throws -> SurfaceCommitPlan {
        let damageMode: DamageCoordinateMode =
            request.surface.usesBufferDamage ? .buffer : .logical
        let plan = request.scaleInstallation.commitPlan(
            geometry: request.geometry,
            damageMode: damageMode
        )

        request.surface.setBufferScale(plan.bufferScale)
        request.scaleInstallation.applyViewportDestinationIfNeeded(plan.viewportDestination)
        request.surface.attach(buffer: request.buffer)
        apply(plan.damage, to: request.surface)
        request.surface.commit()
        try runtime.recordCommittedFrame(generation: request.generation, plan: plan)
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
