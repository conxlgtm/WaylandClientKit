import WaylandRaw

package enum SurfaceCommitPayload {
    case buffer(RawSurfaceBuffer)
    case metadataOnly

    var attachesBuffer: Bool {
        switch self {
        case .buffer:
            true
        case .metadataOnly:
            false
        }
    }
}

struct SurfaceFrameCommitRequest {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let payload: SurfaceCommitPayload

    init(
        surface commitSurface: RawSurface,
        scaleInstallation commitScaleInstallation: SurfaceScaleInstallation,
        generation commitGeneration: UInt64,
        geometry commitGeometry: SurfaceGeometry,
        payload commitPayload: SurfaceCommitPayload,
        submitConstraints commitSubmitConstraints: SurfaceSubmitConstraints = .default,
        metadata commitMetadata: SurfaceCommitMetadata = .default
    ) {
        surface = commitSurface
        scaleInstallation = commitScaleInstallation
        generation = commitGeneration
        geometry = commitGeometry
        payload = commitPayload
        submitConstraints = commitSubmitConstraints
        metadata = commitMetadata
    }
}

package struct PreparedSurfaceFrameCommit {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let plan: SurfaceCommitPlan
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let payload: SurfaceCommitPayload
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
            payload: request.payload
        )
        try request.metadata.validate(capabilities: runtime.capabilitySnapshot())
        return PreparedSurfaceFrameCommit(
            surface: request.surface,
            scaleInstallation: request.scaleInstallation,
            generation: request.generation,
            plan: plan,
            submitConstraints: request.submitConstraints,
            metadata: request.metadata,
            payload: request.payload
        )
    }

    @discardableResult
    static func commit<RoleResources>(
        _ preparedCommit: PreparedSurfaceFrameCommit,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws -> SurfaceCommitPlan {
        try runtime.applySubmitConstraints(preparedCommit.submitConstraints)
        try runtime.applyCommitMetadata(preparedCommit.metadata)
        preparedCommit.surface.setBufferScale(preparedCommit.plan.bufferScale)
        preparedCommit.scaleInstallation.applyViewportDestinationIfNeeded(
            preparedCommit.plan.viewportDestination
        )
        switch preparedCommit.payload {
        case .buffer(let buffer):
            preparedCommit.surface.attach(buffer: buffer)
            apply(preparedCommit.plan.damage, to: preparedCommit.surface)
        case .metadataOnly:
            break
        }
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
