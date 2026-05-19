import WaylandRaw

struct WindowExternalBufferPresentationRequest {
    let buffer: RawSurfaceBuffer
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
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
                payload: .buffer(request.buffer),
                submitConstraints: request.submitConstraints,
                metadata: request.metadata
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
            return try SurfaceFrameCommitter.commit(
                preparedCommit,
                runtime: &runtime
            )
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            throw error
        }
    }
}
