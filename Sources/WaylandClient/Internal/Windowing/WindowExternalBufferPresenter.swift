import WaylandRaw

struct WindowExternalBufferPresentationRequest {
    let buffer: RawSurfaceBuffer
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let onFrameDone: () -> Void
}

enum WindowExternalBufferPresenter {
    static func present<RoleResources>(
        _ request: WindowExternalBufferPresentationRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> SurfaceCommitPlan {
        let preparedCommit = try SurfaceFrameCommitter.prepare(
            SurfaceFrameCommitRequest(
                surface: request.surface,
                scaleInstallation: request.scaleInstallation,
                generation: request.generation,
                geometry: request.geometry,
                submitConstraints: request.submitConstraints
            ),
            runtime: &runtime,
        )

        pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
            on: request.surface,
            runtime: &runtime,
            generation: request.generation,
            onFrame: request.onFrameDone
        )

        do {
            try SurfaceFrameCommitter.recordPreparedCommit(
                preparedCommit,
                runtime: &runtime
            )
            return try SurfaceFrameCommitter.commit(
                preparedCommit,
                buffer: request.buffer,
                runtime: &runtime
            )
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            throw error
        }
    }
}
