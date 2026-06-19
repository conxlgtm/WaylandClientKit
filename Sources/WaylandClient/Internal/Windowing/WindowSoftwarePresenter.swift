import WaylandRaw

struct WindowSoftwarePresentationResult {
    let outcome: RedrawOutcome
    let followUp: WindowSoftwarePresentationFollowUp?
}

enum WindowSoftwarePresentationFollowUp {
    case fail(generation: UInt64, PresentationError)
    case blockedByBuffer
    case resetTransientState
    case succeeded(generation: UInt64)
}

struct WindowSoftwarePresentationFailure: Error {
    let presentationError: PresentationError
    let underlying: any Error
}

package struct WindowSoftwareDrawFailure: Error {
    package let underlying: any Error

    package init(underlying drawError: any Error) {
        underlying = drawError
    }
}

package struct WindowPresentationFeedbackCommitRequest {
    let request: () throws -> SurfacePresentationIdentity
    let cancel: (SurfacePresentationIdentity) -> Void

    package init(
        request feedbackRequest: @escaping () throws -> SurfacePresentationIdentity,
        cancel cancelFeedback: @escaping (SurfacePresentationIdentity) -> Void
    ) {
        request = feedbackRequest
        cancel = cancelFeedback
    }
}

package enum WindowSoftwarePresentationCommitSequence {
    @discardableResult
    package static func perform(
        requestFrameCallback: () throws -> Void,
        requestPresentationFeedback: () throws -> SurfacePresentationIdentity?,
        commit: () throws -> Void,
        cancelFrameCallback: () -> Void,
        cleanupAfterFailure: (SurfacePresentationIdentity?) -> Void
    ) throws -> SurfacePresentationIdentity? {
        do {
            try requestFrameCallback()
        } catch {
            cleanupAfterFailure(nil)
            throw error
        }

        let feedbackIdentity: SurfacePresentationIdentity?
        do {
            feedbackIdentity = try requestPresentationFeedback()
        } catch {
            cancelFrameCallback()
            cleanupAfterFailure(nil)
            throw error
        }

        do {
            try commit()
            return feedbackIdentity
        } catch {
            cancelFrameCallback()
            cleanupAfterFailure(feedbackIdentity)
            throw error
        }
    }
}

struct WindowSoftwarePresentationContext {
    let request: PresentationRequest
    let geometry: SurfaceGeometry
    let submitConstraints: SurfaceSubmitConstraints
    let metadata: SurfaceCommitMetadata
    let damage: SurfaceDamageRegion?
    let presentationFeedback: WindowPresentationFeedbackCommitRequest?
}

private struct WindowSoftwareCommitContext {
    let preparedCommit: PreparedSurfaceFrameCommit
    let request: PresentationRequest
    let presentationFeedback: WindowPresentationFeedbackCommitRequest?
}

struct WindowSoftwarePresenter {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let createSharedMemoryPool: (PositivePixelSize) throws -> RawSharedMemoryPool
    let isWindowClosed: () -> Bool
    let onFrame: () -> Void

    func present<RoleResources>(
        context: WindowSoftwarePresentationContext,
        draw: (borrowing SoftwareFrame) throws -> Void,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> WindowSoftwarePresentationResult {
        guard pendingFrameRegistration == nil else {
            return .init(
                outcome: .skippedPendingFrame,
                followUp: .fail(
                    generation: context.request.generation,
                    .frameCallbackRequest("frame callback is still pending")
                )
            )
        }

        let pool = try runtime.sharedMemoryPool(for: context.geometry.bufferSize) {
            try createSharedMemoryPool(context.geometry.bufferSize)
        }
        runtime.dropReleasedRetiredBufferPools()

        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            return .init(outcome: .waitingForBuffer, followUp: .blockedByBuffer)
        }

        try drawFrame(&drawingBuffer, geometry: context.geometry, draw: draw)

        guard !isWindowClosed() else {
            drawingBuffer.discard()
            return .init(outcome: .skippedClosed, followUp: .resetTransientState)
        }

        let preparedCommit = try prepareCommit(
            request: context.request,
            geometry: context.geometry,
            submitConstraints: context.submitConstraints,
            metadata: context.metadata,
            damage: context.damage,
            runtime: &runtime,
            drawingBuffer: &drawingBuffer
        )
        try performPreparedCommit(
            context: WindowSoftwareCommitContext(
                preparedCommit: preparedCommit,
                request: context.request,
                presentationFeedback: context.presentationFeedback
            ),
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: &drawingBuffer
        )

        return .init(
            outcome: .presented,
            followUp: .succeeded(generation: context.request.generation)
        )
    }

    private func performPreparedCommit<RoleResources>(
        context: WindowSoftwareCommitContext,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws {
        _ = try WindowSoftwarePresentationCommitSequence.perform(
            requestFrameCallback: {
                try requestFrameCallback(
                    request: context.request,
                    runtime: &runtime,
                    pendingFrameRegistration: &pendingFrameRegistration
                )
            },
            requestPresentationFeedback: {
                try requestPresentationFeedback(context.presentationFeedback)
            },
            commit: {
                try recordAndCommit(
                    context: context,
                    runtime: &runtime,
                    drawingBuffer: &drawingBuffer
                )
            },
            cancelFrameCallback: {
                pendingFrameRegistration = nil
                runtime.cancelFrameCallback()
            },
            cleanupAfterFailure: { identity in
                if let identity {
                    context.presentationFeedback?.cancel(identity)
                }
                drawingBuffer.discard()
            }
        )
    }

    private func drawFrame(
        _ drawingBuffer: inout RawBuffer.DrawingBuffer,
        geometry: SurfaceGeometry,
        draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        do {
            try unsafe drawingBuffer.withUnsafeMutableBytes { bytes in
                let frame = try unsafe SoftwareFrame(
                    id: SoftwareFrameBufferID(rawValue: drawingBuffer.objectIdentifier),
                    width: drawingBuffer.width,
                    height: drawingBuffer.height,
                    stride: drawingBuffer.stride,
                    geometry: SoftwareFrameGeometry(surface: geometry),
                    bytes: bytes
                )
                try draw(frame)
            }
        } catch {
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .userDraw(String(describing: error)),
                underlying: error
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func prepareCommit<RoleResources>(
        request: PresentationRequest,
        geometry: SurfaceGeometry,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        damage: SurfaceDamageRegion?,
        runtime: inout SurfaceRuntime<RoleResources>,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws -> PreparedSurfaceFrameCommit {
        do {
            return try SurfaceFrameCommitter.prepare(
                SurfaceFrameCommitRequest(
                    surface: surface,
                    scaleInstallation: scaleInstallation,
                    generation: request.generation,
                    geometry: geometry,
                    payload: .buffer(drawingBuffer.surfaceBuffer),
                    submitConstraints: submitConstraints,
                    metadata: metadata,
                    damage: damage
                ),
                runtime: &runtime,
            )
        } catch {
            drawingBuffer.discard()
            throw WindowSoftwarePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }

    private func requestFrameCallback<RoleResources>(
        request: PresentationRequest,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws {
        do {
            pendingFrameRegistration = try SurfaceFrameCommitter.requestFrameCallback(
                on: surface,
                runtime: &runtime,
                generation: request.generation,
                onFrame: onFrame
            )
        } catch {
            throw WindowSoftwarePresentationFailure(
                presentationError: .frameCallbackRequest(String(describing: error)),
                underlying: error
            )
        }
    }

    private func requestPresentationFeedback(
        _ presentationFeedback: WindowPresentationFeedbackCommitRequest?
    ) throws -> SurfacePresentationIdentity? {
        guard let presentationFeedback else { return nil }

        do {
            return try presentationFeedback.request()
        } catch {
            throw WindowSoftwarePresentationFailure(
                presentationError: .presentationFeedbackRequest(String(describing: error)),
                underlying: error
            )
        }
    }

    private func recordAndCommit<RoleResources>(
        context: WindowSoftwareCommitContext,
        runtime: inout SurfaceRuntime<RoleResources>,
        drawingBuffer: inout RawBuffer.DrawingBuffer
    ) throws {
        do {
            _ = drawingBuffer.markBusy(commitGeneration: context.request.generation)
            try SurfaceFrameCommitter.commit(
                context.preparedCommit,
                runtime: &runtime
            )
        } catch {
            throw WindowSoftwarePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }
}
