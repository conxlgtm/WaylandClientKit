extension PopupRoleSurface {
    // swiftlint:disable:next function_body_length
    func performSoftwarePresent(
        generation: UInt64,
        logicalSize: PositiveLogicalSize,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        presentation = .drawing(generation: generation)

        do {
            guard pendingFrameRegistration == nil else {
                failActivePresentation(generation: generation)
                return .skippedPendingFrame
            }

            let geometry = try surfaceGeometry(logicalSize: logicalSize)
            let pool = try bufferPool(for: geometry.bufferSize)
            dropReleasedRetiredPools()

            guard let buffer = pool.nextFreeBuffer() else {
                _ = redrawState.reduce(.drawBlockedByBuffer, bufferAvailable: false)
                presentation = .idle
                return .waitingForBuffer
            }
            guard buffer.acquireForDrawing() else {
                _ = redrawState.reduce(.drawBlockedByBuffer, bufferAvailable: false)
                presentation = .idle
                return .waitingForBuffer
            }

            do {
                try unsafe buffer.withUnsafeMutableBytes { bytes in
                    let frame = try unsafe SoftwareFrame(
                        width: buffer.width,
                        height: buffer.height,
                        stride: buffer.stride,
                        geometry: SoftwareFrameGeometry(surface: geometry),
                        bytes: bytes
                    )
                    try draw(frame)
                }
            } catch {
                failActivePresentation(generation: generation)
                buffer.markReleased()
                throw error
            }

            guard !isClosedStorage else {
                resetTransientState()
                buffer.markReleased()
                return .skippedClosed
            }

            do {
                pendingFrameRegistration = try surface.requestFrame { [weak self] in
                    self?.handleFrameDone()
                }
            } catch {
                failActivePresentation(generation: generation)
                buffer.markReleased()
                throw error
            }

            precondition(
                buffer.markBusy(commitGeneration: generation),
                "acquired drawing buffer must move to pending release"
            )
            let commitPlan = scaleInstallation.commitPlan(
                geometry: geometry,
                surfaceUsesBufferDamage: surface.usesBufferDamage
            )
            applySurfaceCommitPlan(commitPlan)
            surface.attach(buffer: buffer)
            applySurfaceDamage(commitPlan.damage)
            surface.commit()

            presentation = .idle
            _ = redrawState.reduce(
                .presented(generation: generation),
                bufferAvailable: try redrawBufferAvailable()
            )
            return .presented
        } catch {
            failPresentationIfStillActive(generation: generation)
            throw error
        }
    }
}
