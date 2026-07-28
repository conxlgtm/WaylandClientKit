import WaylandRaw

struct PendingSubsurfaceSoftwareFrameReservation {
    let request: SubsurfacePresentationRequest
    let reservedFrame: ReservedSoftwareSurfaceFrame
}

struct StagedSubsurfacePresentationSuccess {
    let model: SubsurfaceModel
    let publishesRedrawRequest: Bool
}

struct SubsurfacePresentationSuccessStagingContext {
    let model: SubsurfaceModel

    func stage(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> StagedSubsurfacePresentationSuccess {
        var stagedModel = model
        let effects = try stagedModel.reduce(
            .presentationSucceeded(
                generation: generation,
                bufferAvailability: bufferAvailability
            )
        )
        var publishesRedrawRequest = false
        for effect in effects {
            switch effect {
            case .publishRedrawRequested:
                publishesRedrawRequest = true
            case .performSoftwarePresent, .cancelFrameCallback, .retireSwapchain,
                .destroyRoleObjects:
                preconditionFailure("Subsurface success staged an irreversible effect")
            }
        }
        return StagedSubsurfacePresentationSuccess(
            model: stagedModel,
            publishesRedrawRequest: publishesRedrawRequest
        )
    }
}

extension SubsurfaceRoleSurface {
    package func reserveSoftwareFrameForShowOnOwnerThread(
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        connection.preconditionIsOwnerThread()
        return try reserveSoftwareFrame(metadata: metadata)
    }

    package func reserveSoftwareFrameForRedrawOnOwnerThread(
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        connection.preconditionIsOwnerThread()
        return try reserveSoftwareFrame(metadata: metadata)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    package func submitReservedSoftwareFrameOnOwnerThread(
        reservation: SoftwareFrameReservation,
        metadata: SurfaceFrameMetadata,
        makePresentationFeedback: () throws -> SurfacePresentationFeedbackCommitRequest?,
        commitSynchronizedParent: @escaping () -> Void,
        _ draw: (borrowing SoftwareFrame) throws -> Void
    ) throws -> SoftwarePresentationOutcome {
        connection.preconditionIsOwnerThread()

        guard model.lifecycle == .active else { return .closed }
        guard let pendingReservation = softwarePresentationCoordinator.take(reservation) else {
            return .closed
        }

        let request = pendingReservation.request
        let geometry = try currentGeometry()
        guard !Task.isCancelled,
            model.isCurrentSoftwarePresentation(request, geometry: geometry)
        else {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            if model.lifecycle == .closed { return .closed }
            supersedeSoftwarePresentationIfStillActive(generation: request.generation)
            return .superseded
        }

        do {
            try validateSurfaceFrameMetadataSupport(metadata)
            try SurfaceMetadataSupport.ensureObjectsInstalled(
                for: metadata.surfaceCommitMetadata,
                connection: connection,
                surface: surface,
                runtime: &surfaceRuntime
            )
        } catch {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        let presentationFeedback: SurfacePresentationFeedbackCommitRequest?
        do {
            presentationFeedback = try makePresentationFeedback()
        } catch {
            pendingReservation.reservedFrame.drawingBuffer.discard()
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        let successStagingContext = SubsurfacePresentationSuccessStagingContext(model: model)
        var stagedSuccess: StagedSubsurfacePresentationSuccess?
        let commitFollowUp: () -> Void =
            request.synchronizationMode == .synchronized
            ? commitSynchronizedParent
            : {
                // Desynchronized child has no parent commit.
            }

        let result: SoftwareSurfacePresentationResult
        do {
            result = try softwarePresenter().presentReserved(
                pendingReservation.reservedFrame,
                context: SoftwareSurfacePresentationContext(
                    generation: request.generation,
                    geometry: request.geometry,
                    submitConstraints: .default,
                    metadata: metadata.surfaceCommitMetadata,
                    damage: metadata.damage,
                    presentationFeedback: presentationFeedback,
                    commitFollowUp: commitFollowUp
                ),
                draw: draw,
                stageSuccess: { availability in
                    stagedSuccess = try successStagingContext.stage(
                        generation: request.generation,
                        bufferAvailability: availability
                    )
                },
                runtime: &surfaceRuntime,
                pendingFrameRegistration: &pendingFrameRegistration
            )
        } catch let failure as SoftwareSurfacePresentationFailure {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw failure.underlying
        } catch {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }

        if result.outcome == .presented {
            guard let stagedSuccess else {
                preconditionFailure("Subsurface presentation committed without staged success")
            }
            model = stagedSuccess.model
            if stagedSuccess.publishesRedrawRequest {
                onRedrawRequested?()
            }
            return .presented
        }

        try interpretSoftwarePresentationFollowUp(result.followUp)
        return mapPresentationOutcome(result.outcome)
    }

    package func cancelReservedSoftwareFrameOnOwnerThread(
        reservation: SoftwareFrameReservation
    ) throws {
        connection.preconditionIsOwnerThread()
        guard let pendingReservation = softwarePresentationCoordinator.cancel(reservation) else {
            return
        }
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
        guard model.lifecycle == .active else { throw ClientError.display(.closedSubsurface) }

        let feedbackSurface = surface
        let coordinator = presentationFeedbackCoordinator
        let onFailure: (any Error) -> Void = { [weak self] _ in
            self?.surfaceRuntime.resetTransientTransactionState()
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
        outputIDForPresentationSyncOutput: @escaping (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: @escaping (SurfacePresentationFeedback) -> Void
    ) throws -> SurfacePresentationIdentity {
        connection.preconditionIsOwnerThread()
        guard model.lifecycle == .active else { throw ClientError.display(.closedSubsurface) }

        return try presentationFeedbackCoordinator.request(
            presentation: presentation,
            surface: surface,
            outputIDForPresentationSyncOutput: outputIDForPresentationSyncOutput,
            onFeedback: onFeedback
        ) { [weak self] _ in
            self?.surfaceRuntime.resetTransientTransactionState()
        }
    }

    package func cancelPresentationFeedbackOnOwnerThread(_ identity: SurfacePresentationIdentity) {
        connection.preconditionIsOwnerThread()
        presentationFeedbackCoordinator.cancel(identity)
    }
}

extension SubsurfaceRoleSurface {
    private func reserveSoftwareFrame(
        metadata: SurfaceFrameMetadata
    ) throws -> SoftwareSurfaceFrameReservationOutcome {
        guard model.lifecycle == .active else { return .closed }
        try validateSurfaceFrameMetadataSupport(metadata)
        try SurfaceMetadataSupport.ensureObjectsInstalled(
            for: metadata.surfaceCommitMetadata,
            connection: connection,
            surface: surface,
            runtime: &surfaceRuntime
        )
        let geometry = try currentGeometry()
        try metadata.damage?.validate(within: geometry)

        var presentationRequest: SubsurfacePresentationRequest?
        try interpretSubsurfaceEffects(
            model.reduce(
                .redrawRequestConsumed(
                    geometry: geometry,
                    bufferAvailability: try redrawBufferAvailability()
                )
            )
        ) { request in
            presentationRequest = request
        }

        guard let request = presentationRequest else {
            return model.lifecycle == .closed ? .closed : .deferred
        }

        do {
            _ = try model.reduce(.presentationStarted(request))
            let reservationResult = try softwarePresenter().reserve(
                context: SoftwareSurfacePresentationContext(
                    generation: request.generation,
                    geometry: request.geometry,
                    submitConstraints: .default,
                    metadata: metadata.surfaceCommitMetadata,
                    damage: metadata.damage,
                    presentationFeedback: nil
                ),
                reservationID: softwarePresentationCoordinator.allocateIdentity(),
                runtime: &surfaceRuntime,
                hasPendingFrameRegistration: pendingFrameRegistration != nil
            )
            try interpretSoftwarePresentationFollowUp(reservationResult.followUp)

            guard let reservedFrame = reservationResult.reservedFrame else {
                return model.lifecycle == .closed ? .closed : .deferred
            }

            let pendingReservation = PendingSubsurfaceSoftwareFrameReservation(
                request: request,
                reservedFrame: reservedFrame
            )
            softwarePresentationCoordinator.register(
                pendingReservation,
                for: reservedFrame.reservation.reservationID
            )
            return .reserved(reservedFrame.reservation)
        } catch {
            failSoftwarePresentationIfStillActive(generation: request.generation)
            throw error
        }
    }

    private func softwarePresenter() -> SoftwareSurfacePresenter {
        SoftwareSurfacePresenter(
            surface: surface,
            scaleInstallation: surfaceRuntime.scaleInstallation,
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
            isSurfaceClosed: { [self] in model.lifecycle == .closed },
            onFrame: { [weak self] in
                self?.handleFrameDone()
            }
        )
    }

    func redrawBufferAvailability() throws -> RedrawBufferAvailability {
        let geometry = try currentGeometry()
        return surfaceRuntime.redrawBufferAvailability(matching: geometry.bufferSize.rawSize)
    }

    private func interpretSoftwarePresentationFollowUp(
        _ followUp: SoftwareSurfacePresentationFollowUp?
    ) throws {
        guard let followUp else { return }
        switch followUp {
        case .fail(let generation, _):
            failSoftwarePresentationIfStillActive(generation: generation)
        case .blockedByBuffer:
            try interpretSubsurfaceEffects(model.reduce(.presentationBlockedByBuffer))
        case .resetTransientState:
            if case .drawing(let request) = model.presentation {
                failSoftwarePresentationIfStillActive(generation: request.generation)
            }
        case .succeeded:
            preconditionFailure("Subsurface success must be installed from staged state")
        }
    }

    private func supersedeSoftwarePresentationIfStillActive(generation: UInt64) {
        guard case .drawing(let request) = model.presentation,
            request.generation == generation
        else { return }

        do {
            try interpretSubsurfaceEffects(
                model.reduce(
                    .softwarePresentationSuperseded(
                        generation: generation,
                        bufferAvailability: try redrawBufferAvailability()
                    )
                )
            )
        } catch {
            surfaceRuntime.resetTransientTransactionState()
        }
    }

    private func failSoftwarePresentationIfStillActive(generation: UInt64) {
        supersedeSoftwarePresentationIfStillActive(generation: generation)
    }

    private func mapPresentationOutcome(
        _ outcome: RedrawOutcome
    ) -> SoftwarePresentationOutcome {
        switch outcome {
        case .presented:
            .presented
        case .waitingForBuffer, .skippedPendingFrame:
            .deferred
        case .skippedClosed:
            .closed
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
