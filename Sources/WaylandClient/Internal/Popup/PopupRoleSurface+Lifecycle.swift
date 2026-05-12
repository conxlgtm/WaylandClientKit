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
            throw ClientError.invalidWindowState(.unknownPopupGrabSeat(seatID))
        }

        popup.grab(seat: seat, serial: serial.rawValue)
    }

    package func waitForInitialConfigure(timeoutMilliseconds: Int32) throws -> PopupPlacement {
        _ = try Milliseconds(timeoutMilliseconds)

        let timeout = Int64(max(timeoutMilliseconds, 0))
        let deadline = try monotonicMilliseconds() + timeout
        let pollMilliseconds: Int32 = 50

        while !configureState.hasReceivedInitialConfigure, !model.isClosed {
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

        try interpretPopupEffects(model.reduce(.configureReceived(sequence)))
        return sequence
    }

    package func bufferPool(for size: PositivePixelSize) throws -> RawSharedMemoryPool {
        try BufferPoolReplacement.pool(
            for: size.rawSize,
            active: &buffers,
            retired: &retiredBufferPools
        ) {
            guard let globals = connection.boundGlobals else {
                throw ClientError.windowCreationFailed(.requiredGlobalsNotBound)
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
        guard !model.isClosed else { return .skippedClosed }

        let effects = try model.reduce(
            .redrawRequestConsumed(bufferAvailability: try redrawBufferAvailability())
        )
        return try interpretPresentationEffects(effects, draw)
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

    package func failPresentationIfStillActive(
        generation: UInt64,
        error: PresentationError
    ) {
        guard case .drawing(let request) = model.presentation,
            request.generation == generation
        else {
            return
        }

        failActivePresentation(generation: generation, error: error)
    }

    package func failActivePresentation(
        generation: UInt64,
        error: PresentationError = .surfaceCommit("presentation failed")
    ) {
        do {
            try interpretPopupEffects(
                model.reduce(.presentationFailed(generation: generation, error))
            )
        } catch ClientError.window(let windowID, .presentationFailed(let reportedError))
            where windowID == parentWindowID && reportedError == error
        {
            // presentationFailed resets model state before reporting the presentation error.
        } catch {
            preconditionFailure("Unexpected popup presentation failure error: \(error)")
        }
    }

    package func monotonicMilliseconds() throws -> Int64 {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            throw ClientError.windowCreationFailed(.clockGetTimeFailed(errno: errno))
        }

        return Int64(timestamp.tv_sec) * 1_000 + Int64(timestamp.tv_nsec) / 1_000_000
    }

    package func resetTransientState() {
        do {
            resetTransientSurfaceTransactionState()
            _ = try model.reduce(.transientStateReset)
        } catch {
            reportCallbackFailure(operation: .transientStateReset, error: error)
        }
    }

    package func handleFrameDone() {
        do {
            try completeSurfaceFrameCallback()
        } catch {
            reportCallbackFailure(operation: .frameDone, error: error)
        }
        pendingFrameRegistration = nil
        dropReleasedRetiredPools()

        guard !model.isClosed else {
            resetTransientState()
            return
        }

        publishRedrawAfterRedrawStateChange(.frameBecameReady)
    }

    package func handleBufferReleased() {
        connection.preconditionIsOwnerThread()
        dropReleasedRetiredPools()

        guard !model.isClosed, model.redraw.isWaitingForBuffer else { return }

        publishRedrawAfterRedrawStateChange(.bufferBecameAvailable)
    }

    package func handlePreferredBufferScale(_ factor: Int32) {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            let logicalSize = currentLogicalSize
            guard
                try updateScaleResources({ scaleInstallation in
                    try scaleInstallation.updatePreferredBufferScale(
                        factor,
                        logicalSize: logicalSize
                    )
                })
            else { return }
            try markNeedsRedraw(bufferAvailability: .available)
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    package func handlePreferredFractionalScale(_ scale: UInt32) {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        do {
            let logicalSize = currentLogicalSize
            guard
                try updateScaleResources({ scaleInstallation in
                    try scaleInstallation.updatePreferredFractionalScale(
                        scale,
                        logicalSize: logicalSize
                    )
                })
            else { return }
            try markNeedsRedraw(bufferAvailability: .available)
        } catch {
            reportCallbackFailure(operation: .surfaceScaleChanged, error: error)
        }
    }

    package func markNeedsRedraw() {
        do {
            try markNeedsRedraw(bufferAvailability: try redrawBufferAvailability())
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        }
    }

    package func markNeedsRedraw(bufferAvailability: RedrawBufferAvailability) throws {
        guard !model.isClosed else {
            resetTransientState()
            return
        }

        try interpretPopupEffects(
            model.reduce(.contentInvalidated(bufferAvailability: bufferAvailability))
        )
    }

    package var currentLogicalSize: PositiveLogicalSize {
        model.currentLogicalSize
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

    package func redrawBufferAvailability() throws -> RedrawBufferAvailability {
        guard let buffers else { return .available }

        if buffers.size != (try currentSurfaceGeometry()).bufferSize.rawSize {
            return .available
        }

        return RedrawBufferAvailability(isAvailable: buffers.hasFreeBuffers)
    }

    package func handlePopupDone() {
        close(dismissedByCompositor: true)
    }

    package func close(dismissedByCompositor: Bool = false) {
        let event: PopupEvent = dismissedByCompositor ? .compositorDismissed : .explicitClose
        do {
            try interpretPopupEffects(model.reduce(event))
        } catch {
            reportCallbackFailure(operation: .close, error: error)
        }
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
            try interpretPopupEffects(
                model.reduce(
                    popupEvent(
                        for: event,
                        bufferAvailability: try redrawBufferAvailability()
                    )
                )
            )
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
            return
        }
    }

    private func popupEvent(
        for redrawEvent: WindowRedrawEvent,
        bufferAvailability: RedrawBufferAvailability
    ) -> PopupEvent {
        switch redrawEvent {
        case .contentInvalidated:
            .contentInvalidated(bufferAvailability: bufferAvailability)
        case .frameBecameReady:
            .frameBecameReady(bufferAvailability: bufferAvailability)
        case .bufferBecameAvailable:
            .bufferBecameAvailable(bufferAvailability: bufferAvailability)
        case .redrawRequestConsumed:
            .redrawRequestConsumed(bufferAvailability: bufferAvailability)
        case .drawBlockedByBuffer:
            .presentationBlockedByBuffer
        case .presented(let generation):
            .presentationSucceeded(generation: generation, bufferAvailability: bufferAvailability)
        case .transientStateReset:
            .transientStateReset
        }
    }
}
