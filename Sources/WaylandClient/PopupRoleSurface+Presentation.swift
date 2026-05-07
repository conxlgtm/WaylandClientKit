extension PopupRoleSurface {
    // swiftlint:disable:next function_body_length
    func performSoftwarePresent(
        _ request: PopupPresentationRequest,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        try interpretPopupEffects(
            model.reduce(.presentationStarted(generation: request.generation))
        )

        do {
            guard pendingFrameRegistration == nil else {
                failActivePresentation(generation: request.generation)
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
                        width: drawingBuffer.width,
                        height: drawingBuffer.height,
                        stride: drawingBuffer.stride,
                        geometry: SoftwareFrameGeometry(surface: geometry),
                        bytes: bytes
                    )
                    try draw(frame)
                }
            } catch {
                failActivePresentation(generation: request.generation)
                drawingBuffer.discard()
                throw error
            }

            guard !model.isClosed else {
                try interpretPopupEffects(model.reduce(.transientStateReset))
                drawingBuffer.discard()
                return .skippedClosed
            }

            do {
                pendingFrameRegistration = try surface.requestFrame { [weak self] in
                    self?.handleFrameDone()
                }
            } catch {
                failActivePresentation(generation: request.generation)
                drawingBuffer.discard()
                throw error
            }

            let buffer = drawingBuffer.markBusy(commitGeneration: request.generation)
            let commitPlan = scaleInstallation.commitPlan(
                geometry: geometry,
                surfaceUsesBufferDamage: surface.usesBufferDamage
            )
            applySurfaceCommitPlan(commitPlan)
            surface.attach(buffer: buffer)
            applySurfaceDamage(commitPlan.damage)
            surface.commit()

            try interpretPopupEffects(
                model.reduce(
                    .presentationSucceeded(
                        generation: request.generation,
                        bufferAvailable: try redrawBufferAvailable()
                    )
                )
            )
            return .presented
        } catch {
            failPresentationIfStillActive(generation: request.generation)
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
                },
                retireSwapchain: { [self] in
                    retireSwapchain()
                },
                destroyRoleObjects: { [self] in
                    destroyRoleObjects()
                }
            )
        )
    }

    private func destroyRoleObjects() {
        onClose?()
        onClose = nil
        onRedrawRequested = nil

        scaleInstallation.destroy()
        destroyRoleResources()
    }
}
