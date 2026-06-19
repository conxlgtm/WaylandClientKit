extension PopupRoleSurface {
    // swiftlint:disable:next function_body_length
    func performSoftwarePresent(
        _ request: PopupPresentationRequest,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        try interpretPopupEffects(
            model.reduce(.presentationStarted(request))
        )

        do {
            guard pendingFrameRegistration == nil else {
                failActivePresentation(
                    generation: request.generation,
                    error: .frameCallbackRequest("frame callback already pending")
                )
                return .skippedPendingFrame
            }

            let geometry = try surfaceGeometry(logicalSize: request.placement.size)
            let pool = try bufferPool(for: geometry.bufferSize)
            dropReleasedRetiredPools()

            guard var drawingBuffer = pool.acquireDrawingBuffer() else {
                try interpretPopupEffects(model.reduce(.presentationBlockedByBuffer))
                return .waitingForBuffer
            }

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
                failActivePresentation(
                    generation: request.generation,
                    error: .userDraw(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            guard !model.isClosed else {
                try interpretPopupEffects(model.reduce(.transientStateReset))
                drawingBuffer.discard()
                return .skippedClosed
            }

            let preparedCommit: PreparedSurfaceFrameCommit
            do {
                preparedCommit = try prepareSurfaceFrameCommit(
                    generation: request.generation,
                    geometry: geometry,
                    payload: .buffer(drawingBuffer.surfaceBuffer)
                )
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    error: .surfaceCommit(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            do {
                pendingFrameRegistration = try requestSurfaceFrameCallback(
                    generation: request.generation
                ) { [weak self] in
                    self?.handleFrameDone()
                }
            } catch {
                failActivePresentation(
                    generation: request.generation,
                    error: .frameCallbackRequest(String(describing: error))
                )
                drawingBuffer.discard()
                throw error
            }

            do {
                _ = drawingBuffer.markBusy(commitGeneration: request.generation)
                try commitSurfaceFrame(preparedCommit)
            } catch {
                pendingFrameRegistration = nil
                cancelSurfaceFrameCallback()
                drawingBuffer.discard()
                throw error
            }

            try interpretPopupEffects(
                model.reduce(
                    .presentationSucceeded(
                        generation: request.generation,
                        bufferAvailability: try redrawBufferAvailability()
                    )
                )
            )
            return .presented
        } catch {
            failPresentationIfStillActive(
                generation: request.generation,
                error: .surfaceCommit(String(describing: error))
            )
            throw error
        }
    }

    func interpretPresentationEffects(
        _ effects: [PopupEffect],
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        var outcome = RedrawOutcome.skippedPendingFrame

        for effect in effects {
            switch effect {
            case .performSoftwarePresent(let request):
                outcome = try performSoftwarePresent(request, draw)
            default:
                try interpretPopupEffects([effect])
            }
        }

        return effects.isEmpty ? .skippedPendingFrame : outcome
    }

    package func interpretPopupEffects(_ effects: [PopupEffect]) throws {
        try WaylandClient.interpretPopupEffects(
            effects,
            parentWindowID: parentWindowID,
            handlers: PopupEffectHandlers(
                ackConfigure: { [self] serial in
                    try acknowledgeSurfaceConfigure(serial: serial)
                    xdgSurface.ackConfigure(serial: serial)
                },
                publishDismissed: { [self] _ in
                    onDismissed?()
                    onDismissed = nil
                },
                publishClosed: { [self] _ in
                    onClosed?()
                    onClosed = nil
                },
                publishRedrawRequested: { [self] _ in
                    onRedrawRequested?()
                },
                cancelFrameCallback: { [self] in
                    pendingFrameRegistration = nil
                    cancelSurfaceFrameCallback()
                },
                retireSwapchain: { [self] in
                    retireSwapchain()
                },
                destroyRoleObjects: { [self] in
                    try destroyRoleObjects()
                }
            )
        )
    }

    private func destroyRoleObjects() throws {
        onClose?()
        onClose = nil
        onRedrawRequested = nil

        destroyScaleResources()
        try destroyRoleResources()
    }
}
