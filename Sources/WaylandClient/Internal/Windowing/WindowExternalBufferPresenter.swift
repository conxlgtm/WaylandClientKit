import WaylandRaw

struct WindowExternalBufferPresentationRequest {
    let buffer: RawSurfaceBuffer
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let generation: UInt64
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let presentationFeedback: WindowPresentationFeedbackCommitRequest?
    let onFrameDone: () -> Void
}

enum WindowExternalBufferPresenter {
    static func present<RoleResources>(
        _ request: WindowExternalBufferPresentationRequest,
        stageSuccess: (SurfaceCommitPlan) throws -> Void,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> (
        commitPlan: SurfaceCommitPlan,
        presentationFeedbackIdentity: SurfacePresentationIdentity?
    ) {
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
        try SurfaceFrameCommitter.reserveFrameCallback(
            runtime: &runtime,
            generation: request.generation
        )

        do {
            return try performCommitSequence(
                {
                    let stagedCommit = try SurfaceFrameCommitter.stage(
                        preparedCommit,
                        runtime: &runtime
                    )
                    try stageSuccess(stagedCommit.preparedCommit.plan)
                    return stagedCommit
                },
                requestFrameCallback: {
                    pendingFrameRegistration =
                        SurfaceFrameCommitter.requestReservedFrameCallback(
                            on: request.surface,
                            onFrame: request.onFrameDone
                        )
                },
                requestPresentationFeedback: {
                    requestPresentationFeedbackAtPointOfNoReturn(request.presentationFeedback)
                },
                commit: { stagedCommit in
                    SurfaceFrameCommitter.commit(
                        stagedCommit,
                        runtime: &runtime
                    )
                }
            )
        } catch {
            pendingFrameRegistration = nil
            runtime.cancelFrameCallback()
            throw error
        }
    }

    static func performCommitSequence<StagedCommit>(
        _ stageSuccess: () throws -> StagedCommit,
        requestFrameCallback: () -> Void,
        requestPresentationFeedback: () -> SurfacePresentationIdentity?,
        commit: (StagedCommit) -> SurfaceCommitPlan
    ) rethrows -> (
        commitPlan: SurfaceCommitPlan,
        presentationFeedbackIdentity: SurfacePresentationIdentity?
    ) {
        let stagedCommit = try stageSuccess()
        requestFrameCallback()
        let feedbackIdentity = requestPresentationFeedback()
        return (commit(stagedCommit), feedbackIdentity)
    }

    private static func requestPresentationFeedbackAtPointOfNoReturn(
        _ presentationFeedback: WindowPresentationFeedbackCommitRequest?
    ) -> SurfacePresentationIdentity? {
        guard let presentationFeedback else { return nil }

        do {
            return try presentationFeedback.request()
        } catch {
            preconditionFailure(
                "Prepared presentation feedback request failed: \(error)"
            )
        }
    }
}
