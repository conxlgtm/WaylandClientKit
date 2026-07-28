import WaylandRaw

struct StagedPopupPresentationSuccess {
    let model: PopupModel
    let publishesRedrawRequest: Bool
}

struct PopupPresentationSuccessStagingContext {
    let model: PopupModel
    let parentWindowID: WindowID

    func stage(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> StagedPopupPresentationSuccess {
        var stagedModel = model
        let effects = try stagedModel.reduce(
            .presentationSucceeded(
                generation: generation,
                bufferAvailability: bufferAvailability
            )
        )
        let expectedEvent = PopupLifecycleEvent(
            popup: stagedModel.id,
            parentWindowID: parentWindowID
        )
        var publishesRedrawRequest = false
        for effect in effects {
            guard case .publishRedrawRequested(let event) = effect,
                event == expectedEvent,
                !publishesRedrawRequest
            else {
                throw ClientError.window(
                    parentWindowID,
                    .invalidLifecycleTransition(
                        .invalidTransition(
                            from: "popup presentation success staging",
                            event: "unexpected effect \(effect)"
                        )
                    )
                )
            }
            publishesRedrawRequest = true
        }
        return StagedPopupPresentationSuccess(
            model: stagedModel,
            publishesRedrawRequest: publishesRedrawRequest
        )
    }
}

struct PendingPopupSoftwareFrameReservation {
    let request: PopupPresentationRequest
    let geometry: SurfaceGeometry
    let reservedFrame: ReservedSoftwareSurfaceFrame
}

extension PopupRoleSurface {
    package func reserveSoftwareFrameForShowOnOwnerThread(
        timeoutMilliseconds: Int32,
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else { return .closed }
        try validateSurfaceFrameMetadataSupport(metadata)
        if model.currentPlacement == nil {
            _ = try waitForInitialConfigure(timeoutMilliseconds: timeoutMilliseconds)
        } else {
            _ = try consumeLatestConfigureIfAvailable()
        }
        return try reserveSoftwareFrameForCurrentRedraw(metadata: metadata)
    }

    package func reserveSoftwareFrameForRedrawOnOwnerThread(
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else { return .closed }
        try validateSurfaceFrameMetadataSupport(metadata)
        _ = try consumeLatestConfigureIfAvailable()
        return try reserveSoftwareFrameForCurrentRedraw(metadata: metadata)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    package func submitReservedSoftwareFrameOnOwnerThread(
        _ reservation: SoftwareFrameReservation,
        metadata: SurfaceFrameMetadata,
        makePresentationFeedback: () throws -> SurfacePresentationFeedbackCommitRequest?,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> SoftwarePresentationOutcome {
        connection.preconditionIsOwnerThread()

        guard !model.isClosed else { return .closed }
        guard let pendingReservation = softwarePresentationCoordinator.take(reservation) else {
            return model.isClosed ? .closed : .superseded
        }

        let request = pendingReservation.request
        let currentGeometry: SurfaceGeometry
        do {
            _ = try consumeLatestConfigureIfAvailable()
            currentGeometry = try self.currentGeometry()
        } catch {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        guard !model.isClosed else {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            return .closed
        }

        guard
            !Task.isCancelled,
            model.isCurrentSoftwarePresentation(request),
            currentGeometry == pendingReservation.geometry
        else {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            supersedeSoftwarePresentationIfStillActive(generation: request.generation)
            return .superseded
        }

        let presentationFeedback: SurfacePresentationFeedbackCommitRequest?
        do {
            try validateSurfaceFrameMetadataSupport(metadata)
            try metadata.damage?.validate(within: currentGeometry)
            try SurfaceMetadataSupport.ensureObjectsInstalled(
                for: metadata.surfaceCommitMetadata,
                connection: connection,
                surface: surface,
                runtime: &surfaceRuntime
            )
            presentationFeedback = try makePresentationFeedback()
        } catch {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        let successStagingContext = PopupPresentationSuccessStagingContext(
            model: model,
            parentWindowID: parentWindowID
        )
        var stagedSuccess: StagedPopupPresentationSuccess?
        let result: SoftwareSurfacePresentationResult
        do {
            result = try softwarePresenter().presentReserved(
                pendingReservation.reservedFrame,
                context: SoftwareSurfacePresentationContext(
                    generation: request.generation,
                    geometry: currentGeometry,
                    submitConstraints: .default,
                    metadata: metadata.surfaceCommitMetadata,
                    damage: metadata.damage,
                    presentationFeedback: presentationFeedback
                ),
                draw: draw,
                stageSuccess: { currentBufferAvailability in
                    stagedSuccess = try successStagingContext.stage(
                        generation: request.generation,
                        bufferAvailability: currentBufferAvailability
                    )
                },
                runtime: &surfaceRuntime,
                pendingFrameRegistration: &pendingFrameRegistration
            )
        } catch let failure as SoftwareSurfacePresentationFailure {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw failure.underlying
        } catch {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        if result.outcome == .presented {
            guard let stagedSuccess else {
                preconditionFailure("Popup presentation committed without staged success")
            }
            model = stagedSuccess.model
            if stagedSuccess.publishesRedrawRequest {
                onRedrawRequested?()
            }
            return .presented
        }

        try interpretSoftwarePresentationFollowUp(result.followUp)
        return softwarePresentationOutcome(for: result.outcome)
    }

    package func cancelReservedSoftwareFrameOnOwnerThread(
        _ reservation: SoftwareFrameReservation
    ) {
        connection.preconditionIsOwnerThread()
        guard let pendingReservation = softwarePresentationCoordinator.cancel(reservation) else {
            return
        }
        pendingReservation.reservedFrame.drawingBuffer.discard()
        supersedeSoftwarePresentationIfStillActive(
            generation: pendingReservation.request.generation
        )
    }

    package func presentationFeedbackCommitRequestOnOwnerThread(
        presentation: RawPresentation,
        outputIDForPresentationSyncOutput: @escaping (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: @escaping (SurfacePresentationFeedback) -> Void
    ) throws -> SurfacePresentationFeedbackCommitRequest {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else { throw ClientError.display(.unknownPopup) }

        let feedbackSurface = surface
        let coordinator = presentationFeedbackCoordinator
        let onFailure: (any Error) -> Void = { [weak self] error in
            self?.reportCallbackFailure(operation: .presentationFeedback, error: error)
        }
        return SurfacePresentationFeedbackCommitRequest(
            request: {
                try coordinator.request(
                    presentation: presentation,
                    surface: feedbackSurface,
                    outputIDForPresentationSyncOutput: outputIDForPresentationSyncOutput,
                    onFeedback: onFeedback,
                    onFailure: onFailure
                )
            },
            cancel: { identity in
                coordinator.cancel(identity)
            }
        )
    }

    package func requestPresentationFeedbackOnOwnerThread(
        presentation: RawPresentation,
        outputIDForPresentationSyncOutput:
            @escaping (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: @escaping (SurfacePresentationFeedback) -> Void
    ) throws -> SurfacePresentationIdentity {
        connection.preconditionIsOwnerThread()
        guard !model.isClosed else {
            throw ClientError.display(.unknownPopup)
        }

        return try presentationFeedbackCoordinator.request(
            presentation: presentation,
            surface: surface,
            outputIDForPresentationSyncOutput: outputIDForPresentationSyncOutput,
            onFeedback: onFeedback
        ) { [weak self] error in
            self?.reportCallbackFailure(operation: .presentationFeedback, error: error)
        }
    }

    package func cancelPresentationFeedbackOnOwnerThread(
        _ identity: SurfacePresentationIdentity
    ) {
        connection.preconditionIsOwnerThread()
        presentationFeedbackCoordinator.cancel(identity)
    }

    private func reserveSoftwareFrameForCurrentRedraw(
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        let geometry = try currentGeometry()
        try metadata.damage?.validate(within: geometry)
        try SurfaceMetadataSupport.ensureObjectsInstalled(
            for: metadata.surfaceCommitMetadata,
            connection: connection,
            surface: surface,
            runtime: &surfaceRuntime
        )
        let currentBufferAvailability = try redrawBufferAvailability()
        var presentationRequest: PopupPresentationRequest?
        try interpretPopupEffects(
            model.reduce(
                .redrawRequestConsumed(bufferAvailability: currentBufferAvailability)
            )
        ) { request in
            presentationRequest = request
            return .presented
        }

        guard let request = presentationRequest else {
            return model.isClosed ? .closed : .deferred
        }

        try interpretPopupEffects(model.reduce(.presentationStarted(request)))

        do {
            let reservationID = softwarePresentationCoordinator.allocateIdentity()
            let reservationResult = try softwarePresenter().reserve(
                context: SoftwareSurfacePresentationContext(
                    generation: request.generation,
                    geometry: geometry,
                    submitConstraints: .default,
                    metadata: metadata.surfaceCommitMetadata,
                    damage: metadata.damage,
                    presentationFeedback: nil
                ),
                reservationID: reservationID,
                runtime: &surfaceRuntime,
                hasPendingFrameRegistration: pendingFrameRegistration != nil
            )

            if let followUp = reservationResult.followUp {
                try interpretSoftwarePresentationFollowUp(followUp)
            }
            guard let reservedFrame = reservationResult.reservedFrame else {
                return model.isClosed ? .closed : .deferred
            }

            softwarePresentationCoordinator.register(
                PendingPopupSoftwareFrameReservation(
                    request: request,
                    geometry: geometry,
                    reservedFrame: reservedFrame
                ),
                for: reservedFrame.reservation.reservationID
            )
            return .reserved(reservedFrame.reservation)
        } catch let failure as SoftwareSurfacePresentationFailure {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw failure.underlying
        } catch {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }
    }

    private func softwarePresenter() -> SoftwareSurfacePresenter {
        SoftwareSurfacePresenter(
            surface: surface,
            scaleInstallation: scaleInstallation,
            createSharedMemoryPool: { [self] bufferSize in
                guard let globals = connection.boundGlobals else {
                    throw ClientError.windowCreationFailed(.requiredGlobalsNotBound)
                }
                return try globals.sharedMemory.createPool(
                    width: bufferSize.width.rawValue,
                    height: bufferSize.height.rawValue,
                    bufferCount: bufferCount.rawValue
                ) { [weak self] in
                    self?.handleBufferReleased()
                }
            },
            isSurfaceClosed: { [weak self] in self?.model.isClosed ?? true },
            onFrame: { [weak self] in self?.handleFrameDone() }
        )
    }

    private func currentGeometry() throws -> SurfaceGeometry {
        try currentSurfaceGeometry()
    }

    private func interpretSoftwarePresentationFollowUp(
        _ followUp: SoftwareSurfacePresentationFollowUp?
    ) throws {
        guard let followUp else { return }

        switch followUp {
        case .fail(let generation, _):
            failSoftwarePresentationIfStillActive(generation: generation)
        case .blockedByBuffer:
            try interpretPopupEffects(model.reduce(.presentationBlockedByBuffer))
        case .resetTransientState:
            guard case .drawing(let request) = model.presentation else { return }
            supersedeSoftwarePresentationIfStillActive(generation: request.generation)
        case .succeeded:
            preconditionFailure(
                "Popup software-presentation success must be installed from staging")
        }
    }

    private func failSoftwarePresentationIfStillActive(generation: UInt64) {
        supersedeSoftwarePresentationIfStillActive(generation: generation)
    }

    private func supersedeSoftwarePresentationIfStillActive(generation: UInt64) {
        guard case .drawing(let request) = model.presentation,
            request.generation == generation
        else { return }

        do {
            try interpretPopupEffects(
                model.reduce(
                    .softwarePresentationSuperseded(
                        generation: generation,
                        bufferAvailability: try redrawBufferAvailability()
                    )
                )
            )
        } catch {
            reportCallbackFailure(operation: .markNeedsRedraw, error: error)
        }
    }

    private func softwarePresentationOutcome(
        for outcome: RedrawOutcome
    ) -> SoftwarePresentationOutcome {
        switch outcome {
        case .presented:
            return .presented
        case .skippedClosed:
            return .closed
        case .skippedPendingFrame, .waitingForBuffer:
            return .deferred
        }
    }

    private func validateSurfaceFrameMetadataSupport(
        _ metadata: SurfaceFrameMetadata
    ) throws {
        try SurfaceMetadataSupport.validate(
            metadata,
            connection: connection,
            runtime: &surfaceRuntime
        )
    }
}
