import WaylandRaw

enum WindowExternalBufferPresenter {
    static func present<RoleResources>(
        _ buffer: RawSurfaceBuffer,
        on surface: RawSurface,
        scaleInstallation: SurfaceScaleInstallation,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?,
        generation: UInt64,
        geometry: SurfaceGeometry,
        onFrameDone: @escaping () -> Void
    ) throws -> SurfaceCommitPlan {
        let preparedCommit = try SurfaceFrameCommitter.prepare(
            SurfaceFrameCommitRequest(
                surface: surface,
                scaleInstallation: scaleInstallation,
                generation: generation,
                geometry: geometry
            ),
            runtime: &runtime,
        )

        pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
            on: surface,
            runtime: &runtime,
            generation: generation,
            onFrame: onFrameDone
        )

        do {
            try SurfaceFrameCommitter.recordPreparedCommit(
                preparedCommit,
                runtime: &runtime
            )
            return SurfaceFrameCommitter.commit(preparedCommit, buffer: buffer)
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            throw error
        }
    }
}
