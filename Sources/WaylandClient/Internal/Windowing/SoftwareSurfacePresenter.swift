import WaylandRaw

private struct SoftwareSurfaceCommitContext {
    let preparedCommit: PreparedSurfaceFrameCommit
    let generation: UInt64
    let bufferSize: TopLevelSize
    let presentationFeedback: SurfacePresentationFeedbackCommitRequest?
}

// swiftlint:disable:next type_body_length
struct SoftwareSurfacePresenter {
    let surface: RawSurface
    let scaleInstallation: SurfaceScaleInstallation
    let createSharedMemoryPool: (PositivePixelSize) throws -> RawSharedMemoryPool
    let isSurfaceClosed: () -> Bool
    let onFrame: () -> Void

    func present<RoleResources>(
        context: SoftwareSurfacePresentationContext,
        draw: (borrowing SoftwareFrame) throws -> Void,
        stageSuccess: (RedrawBufferAvailability) throws -> Void = { _ in () },
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> SoftwareSurfacePresentationResult {
        guard pendingFrameRegistration == nil else {
            return .init(
                outcome: .skippedPendingFrame,
                followUp: .fail(
                    generation: context.generation,
                    .frameCallbackRequest("frame callback is still pending")
                )
            )
        }
        try validatePresentation(context, runtime: runtime)

        let pool = try runtime.sharedMemoryPool(for: context.geometry.bufferSize) {
            try createSharedMemoryPool(context.geometry.bufferSize)
        }
        runtime.dropReleasedRetiredBufferPools()

        guard var drawingBuffer = pool.acquireDrawingBuffer() else {
            return .init(outcome: .waitingForBuffer, followUp: .blockedByBuffer)
        }

        try drawFrame(&drawingBuffer, geometry: context.geometry, draw: draw)

        guard !isSurfaceClosed() else {
            drawingBuffer.discard()
            return .init(outcome: .skippedClosed, followUp: .resetTransientState)
        }

        let preparedCommit = try prepareCommit(
            generation: context.generation,
            geometry: context.geometry,
            submitConstraints: context.submitConstraints,
            metadata: context.metadata,
            damage: context.damage,
            runtime: &runtime,
            drawingBuffer: &drawingBuffer
        )
        try performPreparedCommit(
            context: SoftwareSurfaceCommitContext(
                preparedCommit: preparedCommit,
                generation: context.generation,
                bufferSize: context.geometry.bufferSize.rawSize,
                presentationFeedback: context.presentationFeedback
            ),
            stageSuccess: stageSuccess,
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: &drawingBuffer
        )

        return .init(
            outcome: .presented,
            followUp: .succeeded(generation: context.generation)
        )
    }

    func reserve<RoleResources>(
        context: SoftwareSurfacePresentationContext,
        reservationID: SoftwareFrameReservationToken,
        runtime: inout SurfaceRuntime<RoleResources>,
        hasPendingFrameRegistration: Bool
    ) throws -> SoftwareSurfaceFrameReservationResult {
        guard !hasPendingFrameRegistration else {
            return .init(
                reservedFrame: nil,
                followUp: .fail(
                    generation: context.generation,
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

        guard !isSurfaceClosed() else {
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
            reservedFrame: ReservedSoftwareSurfaceFrame(
                reservation: reservation,
                drawingBuffer: drawingBuffer
            ),
            followUp: nil
        )
    }

    func presentReserved<RoleResources>(
        _ reservedFrame: ReservedSoftwareSurfaceFrame,
        context: SoftwareSurfacePresentationContext,
        draw: (borrowing SoftwareFrame) throws -> Void,
        stageSuccess: (RedrawBufferAvailability) throws -> Void = { _ in () },
        runtime: inout SurfaceRuntime<RoleResources>,
        pendingFrameRegistration: inout FrameCallbackRegistration?
    ) throws -> SoftwareSurfacePresentationResult {
        guard pendingFrameRegistration == nil else {
            reservedFrame.drawingBuffer.discard()
            return .init(
                outcome: .skippedPendingFrame,
                followUp: .fail(
                    generation: context.generation,
                    .frameCallbackRequest("frame callback is still pending")
                )
            )
        }
        try validatePresentation(context, runtime: runtime)

        try drawReservedFrame(reservedFrame, geometry: context.geometry, draw: draw)

        guard !isSurfaceClosed() else {
            reservedFrame.drawingBuffer.discard()
            return .init(outcome: .skippedClosed, followUp: .resetTransientState)
        }

        let preparedCommit = try prepareReservedCommit(
            generation: context.generation,
            geometry: context.geometry,
            submitConstraints: context.submitConstraints,
            metadata: context.metadata,
            damage: context.damage,
            runtime: &runtime,
            drawingBuffer: reservedFrame.drawingBuffer
        )
        try performPreparedReservedCommit(
            context: SoftwareSurfaceCommitContext(
                preparedCommit: preparedCommit,
                generation: context.generation,
                bufferSize: context.geometry.bufferSize.rawSize,
                presentationFeedback: context.presentationFeedback
            ),
            stageSuccess: stageSuccess,
            runtime: &runtime,
            pendingFrameRegistration: &pendingFrameRegistration,
            drawingBuffer: reservedFrame.drawingBuffer
        )

        return .init(
            outcome: .presented,
            followUp: .succeeded(generation: context.generation)
        )
    }

    private func validatePresentation<RoleResources>(
        _ context: SoftwareSurfacePresentationContext,
        runtime: borrowing SurfaceRuntime<RoleResources>
    ) throws {
        try context.metadata.validate(capabilities: runtime.capabilitySnapshot())
        try context.damage?.validate(within: context.geometry)
    }

    private func performPreparedCommit<RoleResources>(
        context: SoftwareSurfaceCommitContext,
        stageSuccess: (RedrawBufferAvailability) throws -> Void,
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

        let currentBufferAvailability = runtime.redrawBufferAvailability(
            matching: context.bufferSize
        )
        do {
            _ = try SoftwareSurfacePresentationCommitSequence.perform(
                stageSuccess: {
                    try stageSuccess(currentBufferAvailability)
                },
                markDrawingBufferBusy: {
                    _ = drawingBuffer.markBusy(commitGeneration: context.generation)
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
        } catch {
            runtime.cancelFrameCallback()
            drawingBuffer.discard()
            throw error
        }
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
            throw SoftwareSurfacePresentationFailure(
                presentationError: .userDraw(String(describing: error)),
                underlying: error
            )
        }
    }

    private func drawReservedFrame(
        _ reservedFrame: ReservedSoftwareSurfaceFrame,
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
            throw SoftwareSurfacePresentationFailure(
                presentationError: .userDraw(String(describing: error)),
                underlying: error
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func prepareCommit<RoleResources>(
        generation: UInt64,
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
                    generation: generation,
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
            throw SoftwareSurfacePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func prepareReservedCommit<RoleResources>(
        generation: UInt64,
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
                    generation: generation,
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
            throw SoftwareSurfacePresentationFailure(
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
        _ presentationFeedback: SurfacePresentationFeedbackCommitRequest?
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
        context: SoftwareSurfaceCommitContext,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws -> StagedSurfaceFrameCommit {
        do {
            try SurfaceFrameCommitter.reserveFrameCallback(
                runtime: &runtime,
                generation: context.generation
            )
        } catch {
            throw SoftwareSurfacePresentationFailure(
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
            throw SoftwareSurfacePresentationFailure(
                presentationError: .surfaceCommit(String(describing: error)),
                underlying: error
            )
        }
    }

    private func performPreparedReservedCommit<RoleResources>(
        context: SoftwareSurfaceCommitContext,
        stageSuccess: (RedrawBufferAvailability) throws -> Void,
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

        let currentBufferAvailability = runtime.redrawBufferAvailability(
            matching: context.bufferSize
        )
        do {
            _ = try SoftwareSurfacePresentationCommitSequence.perform(
                stageSuccess: {
                    try stageSuccess(currentBufferAvailability)
                },
                markDrawingBufferBusy: {
                    _ = drawingBuffer.markBusy(commitGeneration: context.generation)
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
        } catch {
            runtime.cancelFrameCallback()
            drawingBuffer.discard()
            throw error
        }
    }
}
