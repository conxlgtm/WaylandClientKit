import Glibc
import WaylandRaw

extension PopupRoleSurface {
    package func applyGrabIfNeeded(globals: BoundGlobals) throws {
        guard case .explicit(let seatID, let serial) = configuration.grab else {
            return
        }

        guard
            let seat = globals.seatRegistry.seat(
                for: RawSeatID(rawValue: seatID.rawValue)
            )
        else {
            throw ClientError.invalidWindowState("unknown popup grab seat \(seatID)")
        }

        popup.grab(seat: seat, serial: serial.rawValue)
    }

    package func waitForInitialConfigure(timeoutMilliseconds: Int32) throws -> PopupPlacement {
        _ = try Milliseconds(timeoutMilliseconds)

        let timeout = Int64(max(timeoutMilliseconds, 0))
        let deadline = try monotonicMilliseconds() + timeout
        let pollMilliseconds: Int32 = 50

        while !configureState.hasReceivedInitialConfigure, !isClosedStorage {
            let remainingMilliseconds = deadline - (try monotonicMilliseconds())
            guard remainingMilliseconds > 0 else {
                throw ClientError.window(
                    parentWindowID,
                    .initialConfigureTimedOut(milliseconds: timeoutMilliseconds)
                )
            }

            let boundedRemaining = Int32(min(remainingMilliseconds, Int64(Int32.max)))
            let pumpTimeout = min(boundedRemaining, pollMilliseconds)
            try initialConfigurePump(pumpTimeout)
            try configureState.throwPendingErrorIfAny()
        }

        guard let configure = try consumeLatestConfigureIfAvailable() else {
            throw ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        }

        return configure.placement
    }

    package func consumeLatestConfigureIfAvailable() throws -> PopupConfigureSequence? {
        try configureState.throwPendingErrorIfAny()

        guard let sequence = configureState.consumeLatestConfigure() else {
            return nil
        }

        xdgSurface.ackConfigure(serial: sequence.serial)
        currentPlacement = sequence.placement
        _ = redrawState.reduce(.contentInvalidated, bufferAvailable: true)
        return sequence
    }

    package func bufferPool(for size: PositivePixelSize) throws -> RawSharedMemoryPool {
        try BufferPoolReplacement.pool(
            for: size.rawSize,
            active: &buffers,
            retired: &retiredBufferPools
        ) {
            guard let globals = connection.boundGlobals else {
                throw ClientError.windowCreationFailed("required globals are not bound")
            }

            return try globals.sharedMemory.createPool(
                width: size.width.rawValue,
                height: size.height.rawValue,
                bufferCount: bufferCount.rawValue
            ) { [weak self] in
                self?.handleBufferReleased()
            }
        }
    }

    package func dropReleasedRetiredPools() {
        retiredBufferPools.removeAll { pool in
            !pool.hasBusyBuffers
        }
    }

    package func retireSwapchain() {
        if let activeBuffers = buffers {
            activeBuffers.retire(reason: .windowClosed)
            if activeBuffers.hasBusyBuffers {
                retiredBufferPools.append(activeBuffers)
            }
            buffers = nil
        }

        for pool in retiredBufferPools {
            pool.retire(reason: .windowClosed)
        }
        dropReleasedRetiredPools()
    }

    func drawAndPresent(
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> RedrawOutcome {
        guard !isClosedStorage else { return .skippedClosed }

        guard redrawState.hasOutstandingRedrawRequest else {
            return .skippedPendingFrame
        }
        _ = redrawState.reduce(
            .redrawRequestConsumed,
            bufferAvailable: try redrawBufferAvailable()
        )
        guard let placement = currentPlacement else {
            throw ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        }
        let generation = redrawState.generationForCurrentDraw
        return try performSoftwarePresent(
            generation: generation,
            logicalSize: placement.size,
            draw
        )
    }

    package func applySurfaceCommitPlan(_ plan: SurfaceCommitPlan) {
        surface.setBufferScale(plan.bufferScale)
        scaleInstallation.applyViewportDestinationIfNeeded(plan.viewportDestination)
    }

    package func applySurfaceDamage(_ damage: SurfaceDamageExtent) {
        switch damage {
        case .buffer(let width, let height):
            surface.damageFullBuffer(width: width, height: height)
        case .logical(let width, let height):
            surface.damageFullLogical(width: width, height: height)
        }
    }

    package func failPresentationIfStillActive(generation: UInt64) {
        guard presentation == .drawing(generation: generation) else { return }

        failActivePresentation(generation: generation)
    }

    package func failActivePresentation(generation _: UInt64) {
        presentation = .idle
    }

    package func monotonicMilliseconds() throws -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw ClientError.windowCreationFailed("clock_gettime failed with errno \(errno)")
        }

        return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
    }

    package func resetTransientState() {
        _ = redrawState.reduce(.transientStateReset, bufferAvailable: false)
        presentation = .idle
    }

    package func handleFrameDone() {
        pendingFrameRegistration = nil
        dropReleasedRetiredPools()

        guard !isClosedStorage else {
            resetTransientState()
            return
        }

        publishRedrawAfterRedrawStateChange(.frameBecameReady)
    }

    package func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        dropReleasedRetiredPools()

        guard !isClosedStorage, redrawState.isWaitingForBuffer else { return }

        publishRedrawAfterRedrawStateChange(.bufferBecameAvailable)
    }

    package func handlePreferredBufferScale(_ factor: Int32) {
        do {
            guard
                try scaleInstallation.updatePreferredBufferScale(
                    factor,
                    logicalSize: currentLogicalSize
                )
            else { return }
            try markNeedsRedraw(bufferAvailable: true)
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    package func handlePreferredFractionalScale(_ scale: UInt32) {
        do {
            guard
                try scaleInstallation.updatePreferredFractionalScale(
                    scale,
                    logicalSize: currentLogicalSize
                )
            else { return }
            try markNeedsRedraw(bufferAvailable: true)
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    package func markNeedsRedraw() {
        do {
            try markNeedsRedraw(bufferAvailable: try redrawBufferAvailable())
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        }
    }

    package func markNeedsRedraw(bufferAvailable: Bool) throws {
        guard !isClosedStorage else {
            resetTransientState()
            return
        }

        let effects = redrawState.reduce(.contentInvalidated, bufferAvailable: bufferAvailable)
        if effects.contains(.publishRedrawRequested) {
            onRedrawRequested?()
        }
    }

    package var currentLogicalSize: PositiveLogicalSize {
        currentPlacement?.size ?? configuration.positioner.size
    }

    package func currentSurfaceGeometry() throws -> SurfaceGeometry {
        try surfaceGeometry(logicalSize: currentLogicalSize)
    }

    package func surfaceGeometry(logicalSize: PositiveLogicalSize) throws -> SurfaceGeometry {
        do {
            return try scaleInstallation.geometry(logicalSize: logicalSize)
        } catch let error as WindowError {
            throw ClientError.window(parentWindowID, error)
        }
    }

    package func redrawBufferAvailable() throws -> Bool {
        guard let buffers else { return true }

        if buffers.size != (try currentSurfaceGeometry()).bufferSize.rawSize {
            return true
        }

        return buffers.hasFreeBuffers
    }

    package func handlePopupDone() {
        close(dismissedByCompositor: true)
    }

    package func close(dismissedByCompositor: Bool = false) {
        guard !isClosedStorage else { return }

        isClosedStorage = true
        onClose?()
        onClose = nil
        onRedrawRequested = nil
        pendingFrameRegistration = nil
        retireSwapchain()
        scaleInstallation.destroy()
        popupOwner?.cancel()
        popupOwner = nil
        xdgSurfaceOwner.cancel()
        popup.destroy()
        positioner.destroy()
        xdgSurface.destroy()
        surface.destroy()

        if dismissedByCompositor {
            onDismissed?()
            onDismissed = nil
        }
        onClosed?()
        onClosed = nil
    }

    package func reportCallbackFailure(operation: WindowCallbackOperation, error: any Error) {
        let classifiedError: any Error
        if let windowError = error as? WindowError {
            classifiedError = ClientError.window(parentWindowID, windowError)
        } else {
            classifiedError = error
        }

        failureSink.reportWindowFailure(
            WindowFailureClassifier.classify(
                windowID: parentWindowID,
                operation: operation,
                error: classifiedError
            )
        )
    }

    private func publishRedrawAfterRedrawStateChange(_ event: WindowRedrawEvent) {
        do {
            _ = redrawState.reduce(
                event,
                bufferAvailable: try redrawBufferAvailable()
            )
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
            return
        }

        if redrawState.hasOutstandingRedrawRequest {
            onRedrawRequested?()
        }
    }
}
