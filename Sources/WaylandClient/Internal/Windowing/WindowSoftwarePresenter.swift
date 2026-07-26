import WaylandRaw

struct WindowSoftwarePresentationResult {
    let outcome: RedrawOutcome
    let followUp: WindowSoftwarePresentationFollowUp?
}

struct WindowReservedSoftwareFrame {
    let reservation: SoftwareFrameReservation
    let drawingBuffer: RawBuffer.ReservedDrawingBuffer
}

struct WindowSoftwareFrameReservationResult {
    let reservedFrame: WindowReservedSoftwareFrame?
    let followUp: WindowSoftwarePresentationFollowUp?
}

package enum WindowSoftwareFrameReservationOutcome: Equatable, Sendable {
    case reserved(SoftwareFrameReservation)
    case deferred
    case closed
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
        markDrawingBufferBusy: () -> Void,
        requestFrameCallback: () -> Void,
        requestPresentationFeedback: () -> SurfacePresentationIdentity?,
        commit: () -> Void
    ) -> SurfacePresentationIdentity? {
        markDrawingBufferBusy()
        requestFrameCallback()
        let feedbackIdentity = requestPresentationFeedback()
        commit()
        return feedbackIdentity
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

// swiftlint:disable:next type_body_length
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

    func reserve<RoleResources>(
        context: WindowSoftwarePresentationContext,
        reservationID: SoftwareFrameReservationToken,
        runtime: inout SurfaceRuntime<RoleResources>,
        hasPendingFrameRegistration: Bool
    ) throws -> WindowSoftwareFrameReservationResult {
        guard !hasPendingFrameRegistration else {
            return .init(
                reservedFrame: nil,
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

        guard let drawingBuffer = pool.acquireReservedDrawingBuffer() else {
            return .init(reservedFrame: nil, followUp: .blockedByBuffer)
        }

        guard !isWindowClosed() else {
            drawingBuffer.discard()
            return .init(reservedFrame: nil, followUp: .resetTransientState)
        }

        let reservation = SoftwareFrameReservation(
            reservationID: reservationID,
            id: SoftwareFrameBufferID(rawValue: drawingBuffer.identity),
            width: drawingBuffer.width,
            height: drawingBuffer.height,
            stride: drawingBuffer.stride,
            geometry: SoftwareFrameGeometry(surface: context.geometry)
        )
        return .init(
            reservedFrame: WindowReservedSoftwareFrame(
                reservation: reservation,
                drawingBuffer: drawingBuffer
            ),
            followUp: nil
        )
    }

    func presentReserved<RoleResources>(
        _ reservedFrame: WindowReservedSoftwareFrame,
        context: WindowSoftwarePresentationContext,
        draw: (borrowing SoftwareFrame) throws -> Void,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> WindowSoftwarePresentationResult {
        guard pendingFrameRegistration == nil else {
            reservedFrame.drawingBuffer.discard()
            return .init(
                outcome: .skippedPendingFrame,
                followUp: .fail(
                    generation: context.request.generation,
                    .frameCallbackRequest("frame callback is still pending")
                )
            )
        }

        try drawReservedFrame(reservedFrame, geometry: context.geometry, draw: draw)

        guard !isWindowClosed() else {
            reservedFrame.drawingBuffer.discard()
            return .init(outcome: .skippedClosed, followUp: .resetTransientState)
        }

        let preparedCommit = try prepareReservedCommit(
            request: context.request,
            geometry: context.geometry,
            submitConstraints: context.submitConstraints,
            metadata: context.metadata,
            damage: context.damage,
            runtime: &runtime,
            drawingBuffer: reservedFrame.drawingBuffer
        )
        try performPreparedReservedCommit(
            context: WindowSoftwareCommitContext(
                preparedCommit: preparedCommit,
                request: context.request,
                presentationFeedback: context.presentationFeedback
            ),
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: reservedFrame.drawingBuffer
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
        let stagedCommit: StagedSurfaceFrameCommit
        do {
            stagedCommit = try stageCommit(context: context, runtime: &runtime)
        } catch {
            drawingBuffer.discard()
            throw error
        }

        _ = WindowSoftwarePresentationCommitSequence.perform(
            markDrawingBufferBusy: {
                _ = drawingBuffer.markBusy(commitGeneration: context.request.generation)
            },
            requestFrameCallback: {
                requestReservedFrameCallback(
                    pendingFrameRegistration: &pendingFrameRegistration
                )
            },
            requestPresentationFeedback: {
                requestPresentationFeedbackAtPointOfNoReturn(
                    context.presentationFeedback
                )
            },
            commit: {
                SurfaceFrameCommitter.commit(
                    stagedCommit,
                    runtime: &runtime,
                )
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
                    id: SoftwareFrameBufferID(rawValue: drawingBuffer.identity),
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

    private func drawReservedFrame(
        _ reservedFrame: WindowReservedSoftwareFrame,
        geometry: SurfaceGeometry,
        draw: (borrowing SoftwareFrame) throws -> Void
    ) throws {
        do {
            try unsafe reservedFrame.drawingBuffer.withUnsafeMutableBytes { bytes in
                let frame = try unsafe SoftwareFrame(
                    id: reservedFrame.reservation.id,
                    width: reservedFrame.drawingBuffer.width,
                    height: reservedFrame.drawingBuffer.height,
                    stride: reservedFrame.drawingBuffer.stride,
                    geometry: SoftwareFrameGeometry(surface: geometry),
                    bytes: bytes
                )
                try draw(frame)
            }
        } catch {
            reservedFrame.drawingBuffer.discard()
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

    // swiftlint:disable:next function_parameter_count
    private func prepareReservedCommit<RoleResources>(
        request: PresentationRequest,
        geometry: SurfaceGeometry,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        damage: SurfaceDamageRegion?,
        runtime: inout SurfaceRuntime<RoleResources>,
        drawingBuffer: RawBuffer.ReservedDrawingBuffer
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

    private func requestReservedFrameCallback(
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) {
        pendingFrameRegistration = SurfaceFrameCommitter.requestReservedFrameCallback(
            on: surface,
            onFrame: onFrame
        )
    }

    private func requestPresentationFeedbackAtPointOfNoReturn(
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

    private func stageCommit<RoleResources>(
        context: WindowSoftwareCommitContext,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws -> StagedSurfaceFrameCommit {
        do {
            try SurfaceFrameCommitter.reserveFrameCallback(
                runtime: &runtime,
                generation: context.request.generation
            )
        } catch {
            throw WindowSoftwarePresentationFailure(
                presentationError: .frameCallbackRequest(String(describing: error)),
                underlying: error
            )
        }

        do {
            return try SurfaceFrameCommitter.stage(
                context.preparedCommit,
                runtime: &runtime,
            )
        } catch {
            runtime.cancelFrameCallback()
            throw WindowSoftwarePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }

    private func performPreparedReservedCommit<RoleResources>(
        context: WindowSoftwareCommitContext,
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?,
        drawingBuffer: RawBuffer.ReservedDrawingBuffer
    ) throws {
        let stagedCommit: StagedSurfaceFrameCommit
        do {
            stagedCommit = try stageCommit(context: context, runtime: &runtime)
        } catch {
            drawingBuffer.discard()
            throw error
        }

        _ = WindowSoftwarePresentationCommitSequence.perform(
            markDrawingBufferBusy: {
                _ = drawingBuffer.markBusy(commitGeneration: context.request.generation)
            },
            requestFrameCallback: {
                requestReservedFrameCallback(
                    pendingFrameRegistration: &pendingFrameRegistration
                )
            },
            requestPresentationFeedback: {
                requestPresentationFeedbackAtPointOfNoReturn(
                    context.presentationFeedback
                )
            },
            commit: {
                SurfaceFrameCommitter.commit(
                    stagedCommit,
                    runtime: &runtime,
                )
            }
        )
    }
}
