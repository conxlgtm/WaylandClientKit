import WaylandRaw

struct SurfaceFrameCommitRequest {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let attachesBuffer: Bool

    init(
        surface commitSurface: RawSurface,
        scaleInstallation commitScaleInstallation: SurfaceScaleInstallation,
        generation commitGeneration: UInt64,
        geometry commitGeometry: SurfaceGeometry,
        submitConstraints commitSubmitConstraints: SurfaceSubmitConstraints = .default,
        metadata commitMetadata: SurfaceCommitMetadata = .default,
        attachesBuffer commitAttachesBuffer: Bool = true
    ) {
        surface = commitSurface
        scaleInstallation = commitScaleInstallation
        generation = commitGeneration
        geometry = commitGeometry
        submitConstraints = commitSubmitConstraints
        metadata = commitMetadata
        attachesBuffer = commitAttachesBuffer
    }
}

package struct PreparedSurfaceFrameCommit {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let plan: SurfaceCommitPlan
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let attachesBuffer: Bool
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
    static func prepare<RoleResources>(
        _ request: SurfaceFrameCommitRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
    ) throws -> PreparedSurfaceFrameCommit {
        let damageMode: DamageCoordinateMode =
            request.surface.usesBufferDamage ? .buffer : .logical
        let plan = request.scaleInstallation.commitPlan(
            geometry: request.geometry,
            damageMode: damageMode
        )

        try runtime.validateCommittedFrameCandidate(generation: request.generation)
        try request.submitConstraints.validate(
            capabilities: runtime.capabilitySnapshot(),
            attachesBuffer: request.attachesBuffer
        )
        try request.metadata.validate(capabilities: runtime.capabilitySnapshot())
        return PreparedSurfaceFrameCommit(
            surface: request.surface,
            scaleInstallation: request.scaleInstallation,
            generation: request.generation,
            plan: plan,
            submitConstraints: request.submitConstraints,
            metadata: request.metadata,
            attachesBuffer: request.attachesBuffer
        )
    }

    @discardableResult
    static func commit<RoleResources>(
        _ preparedCommit: PreparedSurfaceFrameCommit,
        buffer: RawBuffer,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws -> SurfaceCommitPlan {
        try commit(preparedCommit, buffer: buffer.surfaceBuffer, runtime: &runtime)
    }

    @discardableResult
    static func commit<RoleResources>(
        _ preparedCommit: PreparedSurfaceFrameCommit,
        buffer: RawSurfaceBuffer,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws -> SurfaceCommitPlan {
        try runtime.applySubmitConstraints(preparedCommit.submitConstraints)
        try runtime.applyCommitMetadata(preparedCommit.metadata)
        preparedCommit.surface.setBufferScale(preparedCommit.plan.bufferScale)
        preparedCommit.scaleInstallation.applyViewportDestinationIfNeeded(
            preparedCommit.plan.viewportDestination
        )
        preparedCommit.surface.attach(buffer: buffer)
        apply(preparedCommit.plan.damage, to: preparedCommit.surface)
        preparedCommit.surface.commit()
        try runtime.prepareCommittedFrame(
            generation: preparedCommit.generation,
            plan: preparedCommit.plan
        )
        runtime.markSubmitConstraintsCommitted()
        return preparedCommit.plan
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
