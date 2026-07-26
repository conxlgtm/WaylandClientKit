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

        return try performCommitSequence(
            requestFrameCallback: {
                pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
                    on: request.surface,
                    runtime: &runtime,
                    generation: request.generation,
                    onFrame: request.onFrameDone
                )
            },
            requestPresentationFeedback: {
                try request.presentationFeedback?.request()
            },
            commit: {
                try SurfaceFrameCommitter.commit(
                    preparedCommit,
                    runtime: &runtime
                )
            },
            cancelFrameCallback: {
                pendingFrameRegistration = nil
                runtime.cancelFrameCallback()
            },
            cancelPresentationFeedback: { feedbackIdentity in
                request.presentationFeedback?.cancel(feedbackIdentity)
            }
        )
    }

    static func performCommitSequence(
        requestFrameCallback: () throws -> Void,
        requestPresentationFeedback: () throws -> SurfacePresentationIdentity?,
        commit: () throws -> SurfaceCommitPlan,
        cancelFrameCallback: () -> Void,
        cancelPresentationFeedback: (SurfacePresentationIdentity) -> Void
    ) throws -> (
        commitPlan: SurfaceCommitPlan,
        presentationFeedbackIdentity: SurfacePresentationIdentity?
    ) {
        try requestFrameCallback()

        let feedbackIdentity: SurfacePresentationIdentity?
        do {
            feedbackIdentity = try requestPresentationFeedback()
        } catch {
            cancelFrameCallback()
            throw error
        }

        do {
            return (try commit(), feedbackIdentity)
        } catch {
            cancelFrameCallback()
            if let feedbackIdentity {
                cancelPresentationFeedback(feedbackIdentity)
            }
            throw error
        }
    }
}
