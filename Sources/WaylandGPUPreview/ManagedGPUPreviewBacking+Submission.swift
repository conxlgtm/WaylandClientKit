import Glibc
import WaylandClient
import WaylandGraphicsCore
import WaylandRaw

extension ManagedGPUPreviewBacking {
    func prepareClearFrameSubmission(
        metadata: SurfaceCommitMetadata,
        geometry: SurfaceGeometry,
        synchronizationPolicy: GPUSynchronizationPolicy,
        pacingPolicy: GPUFramePacingPolicy,
        requestPresentationFeedback: Bool
    ) async throws(ManagedGPUPreviewBackingError) -> ManagedGPUPreviewSubmissionContext {
        do {
            try await ensureConfigured(geometry: geometry)
            guard let renderTarget, let capabilities else {
                throw ManagedGPUPreviewBackingError.closed
            }

            let synchronization = try await resolveSynchronization(
                policy: synchronizationPolicy,
                capabilities: capabilities
            )
            let pacingSelection = try resolvePacing(
                policy: pacingPolicy,
                capabilities: capabilities
            )
            try validateSubmissionRequirements(
                synchronization: synchronization,
                pacing: pacingSelection.constraint,
                metadata: metadata,
                capabilities: capabilities
            )

            return ManagedGPUPreviewSubmissionContext(
                capabilities: capabilities,
                renderTarget: renderTarget,
                options: ManagedGPUPreviewPresentationOptions(
                    metadata: metadata,
                    synchronization: synchronization,
                    pacing: pacingSelection.constraint,
                    pacingFallbackReason: pacingSelection.fallbackReason,
                    requestPresentationFeedback: requestPresentationFeedback
                )
            )
        } catch let error as ManagedGPUPreviewBackingError {
            recordFailure(error)
            throw error
        } catch {
            let error = ManagedGPUPreviewBackingError.setup(.commitFailed)
            recordFailure(error)
            throw error
        }
    }

    func renderAndImportBuffer(
        renderTarget: EGLGBMRenderTarget,
        color: GPUClearColor
    ) async throws(ManagedGPUPreviewBackingError) -> (
        buffer: RawLinuxDmabufBuffer,
        lockedBuffer: GBMLockedSurfaceBuffer
    ) {
        do {
            _ = try renderTarget.drawClear(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
            let lockedBuffer = try renderTarget.lockFrontBuffer()
            let export = try lockedBuffer.exportDmabuf()
            // swiftlint:disable closure_parameter_position
            let importedBuffer = try await window.withGraphicsPreviewLinuxDmabuf {
                linuxDmabuf, syncDisplay in
                try GPUDmabufBufferImport.importBuffer(
                    from: export,
                    using: linuxDmabuf,
                    timeoutMilliseconds: WaylandDisplay.defaultDiscoveryTimeoutMilliseconds,
                    syncDisplay: syncDisplay
                )
            }
            // swiftlint:enable closure_parameter_position

            return (importedBuffer, lockedBuffer)
        } catch let error as EGLRenderError {
            throw .render(error)
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as GPUDmabufBufferImportError {
            throw .dmabufImport(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.commitFailed)
        }
    }

    func presentImportedBuffer(
        _ imported: (buffer: RawLinuxDmabufBuffer, lockedBuffer: GBMLockedSurfaceBuffer),
        renderTarget: EGLGBMRenderTarget,
        options: ManagedGPUPreviewPresentationOptions
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        do {
            let slotID: GBMBufferPoolSlotID
            let previewBuffer = ManagedGPUPreviewBuffer(
                buffer: imported.buffer,
                lockedBuffer: imported.lockedBuffer,
                renderTarget: renderTarget
            )
            try reapExplicitReleaseSignalsIfAvailable()
            if let reusableSlotID = presenter.availableSlotIDs.first {
                slotID = reusableSlotID
                try presenter.replaceAvailableBuffer(previewBuffer, slotID: reusableSlotID)
            } else {
                slotID = try nextSlotID()
                try presenter.installBuffer(previewBuffer, slotID: slotID)
            }

            let synchronization = try options.synchronization.submissionSynchronization(
                for: slotID
            )
            let frame = try await presenter.presentSlot(
                slotID,
                submit: { [window] buffer, submitConstraints, commitMetadata in
                    try await window.presentGraphicsPreviewBuffer(
                        buffer,
                        submitConstraints: submitConstraints,
                        metadata: commitMetadata,
                        requestPresentationFeedback: options.requestPresentationFeedback
                    )
                },
                synchronization: synchronization,
                pacing: options.pacing,
                metadata: options.metadata
            )
            updateRuntimePathAfterPresentation(options: options)
            return frame
        } catch let error as ManagedGPUPreviewBackingError {
            throw error
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as GPUWindowPresenterError {
            if let failure = error.committedFrameFailure {
                throw .committedFrame(failure)
            }
            throw .presentation(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.commitFailed)
        }
    }

    func validateSubmissionRequirements(
        synchronization: ManagedGPUPreviewSynchronizationSelection,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata,
        capabilities: SurfaceCapabilitySnapshot
    ) throws(ManagedGPUPreviewBackingError) {
        do {
            try GPUBackingRequirements(
                synchronization: synchronization.requirementSynchronization,
                pacing: pacing,
                metadata: metadata
            ).validate(capabilities: capabilities)
        } catch {
            throw .setup(GPUBackingFailure(error))
        }
    }

    func reapExplicitReleaseSignalsIfAvailable() throws(ManagedGPUPreviewBackingError) {
        let explicitSubmissionStates = presenter.explicitSubmissionStates
        guard !explicitSubmissionStates.isEmpty else {
            destroyUnusedRetainedExplicitSynchronizations()
            return
        }

        for state in explicitSubmissionStates {
            guard
                let synchronization = explicitSynchronizationTimeline(
                    for: state.releasePoint.timeline
                )
            else {
                runtimePath = presenter.runtimePathSnapshot.markingFailure(
                    .explicitSyncReleaseFailed
                )
                throw .setup(.explicitSyncReleaseFailed)
            }

            do {
                guard try synchronization.releasePointIsSignaled(state) else {
                    continue
                }
                try presenter.recordExplicitReleaseSignal(slotID: state.slotID)
            } catch let error as GBMAllocationError {
                let failure = ManagedGPUPreviewBackingError.backingFailure(for: error)
                runtimePath = presenter.runtimePathSnapshot.markingFailure(failure)
                throw .setup(failure)
            } catch let error as GPUWindowPresenterError {
                let failure = ManagedGPUPreviewBackingError.backingFailure(for: error)
                runtimePath = presenter.runtimePathSnapshot.markingFailure(failure)
                throw .setup(failure)
            } catch {
                runtimePath = presenter.runtimePathSnapshot.markingFailure(.commitFailed)
                throw .setup(.commitFailed)
            }
        }
        destroyUnusedRetainedExplicitSynchronizations()
    }

    func explicitSynchronizationTimeline(
        for timeline: GPUSyncTimeline
    ) -> ManagedGPUExplicitSynchronization? {
        if explicitSynchronization?.timelineIdentity == timeline {
            return explicitSynchronization
        }

        return retainedExplicitSynchronizations[timeline]?.synchronization
    }

    func updateRuntimePathAfterPresentation(options: ManagedGPUPreviewPresentationOptions) {
        var snapshot = presenter.runtimePathSnapshot
        if let fallbackReason = options.synchronization.fallbackReason {
            snapshot = snapshot.markingSynchronizationFallback(fallbackReason)
        }
        if let fallbackReason = options.pacingFallbackReason {
            snapshot = snapshot.markingPacingFallback(fallbackReason)
        }
        runtimePath = snapshot
        if let surfaceCapabilities = presenter.backingStateSnapshot.surfaceCapabilities {
            capabilities = surfaceCapabilities
        }
    }

    func resolveSynchronization(
        policy: GPUSynchronizationPolicy,
        capabilities: SurfaceCapabilitySnapshot
    ) async throws(ManagedGPUPreviewBackingError) -> ManagedGPUPreviewSynchronizationSelection {
        switch policy {
        case .implicitOnly:
            return .implicit()
        case .preferExplicitFallbackToImplicit:
            guard capabilities.synchronization.supportsExplicit else {
                return .implicit(fallbackReason: .explicitSynchronizationUnavailable)
            }
            do {
                return .explicit(try await ensureExplicitSynchronizationConfigured())
            } catch let error {
                return .implicit(
                    fallbackReason: explicitSynchronizationFallbackReason(for: error)
                )
            }
        case .requireExplicit:
            guard capabilities.synchronization.supportsExplicit else {
                throw .setup(.explicitSyncRequiredButUnavailable)
            }
            do {
                return .explicit(try await ensureExplicitSynchronizationConfigured())
            } catch let error {
                throw .setup(explicitSynchronizationFailure(for: error))
            }
        }
    }

    func ensureExplicitSynchronizationConfigured()
        async throws(ManagedGPUPreviewBackingError) -> ManagedGPUExplicitSynchronization
    {
        if let explicitSynchronization {
            return explicitSynchronization
        }
        guard let device else {
            throw .setup(.explicitSyncRequiredButUnavailable)
        }

        do {
            let timelineIdentity = GPUSyncTimeline(nextSyncTimelineRawValue)
            nextSyncTimelineRawValue += 1
            let timeline = try DRMSyncobjTimeline(
                deviceFileDescriptor: try device.drmFileDescriptor
            )
            var timelineFileDescriptor = try timeline.exportFileDescriptor()
            try await window.importGraphicsPreviewSynchronizationTimeline(
                &timelineFileDescriptor,
                identity: SurfaceSyncTimelineIdentity(timelineIdentity.rawValue)
            )
            let synchronization = ManagedGPUExplicitSynchronization(
                timeline: timeline,
                identity: timelineIdentity
            )
            explicitSynchronization = synchronization
            return synchronization
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.explicitSyncRequiredButUnavailable)
        }
    }

    func explicitSynchronizationFallbackReason(
        for error: ManagedGPUPreviewBackingError
    ) -> GPURuntimePathReason {
        switch error.failure {
        case .explicitSyncSetupFailed:
            .explicitSynchronizationSetupFailed
        case .explicitSyncSubmissionFailed:
            .explicitSynchronizationSubmissionFailed
        case .explicitSyncReleaseFailed:
            .explicitSynchronizationReleaseFailed
        case .explicitSyncRequiredButUnavailable:
            .explicitSynchronizationUnavailable
        default:
            .explicitSynchronizationNotConfigured
        }
    }

    func explicitSynchronizationFailure(
        for error: ManagedGPUPreviewBackingError
    ) -> GPUBackingFailure {
        switch error.failure {
        case .explicitSyncSetupFailed, .explicitSyncSubmissionFailed,
            .explicitSyncReleaseFailed, .explicitSyncRequiredButUnavailable:
            error.failure
        default:
            .explicitSyncRequiredButUnavailable
        }
    }

    func resolvePacing(
        policy: GPUFramePacingPolicy,
        capabilities: SurfaceCapabilitySnapshot
    ) throws(ManagedGPUPreviewBackingError) -> GPUFramePacingPolicySelection {
        do {
            return policy.selectConstraint(
                capability: capabilities.pacing,
                commitTimingTarget: try nextCommitTimingTarget()
            )
        } catch {
            throw .setup(.commitTimingRequiredButUnavailable)
        }
    }

    func nextCommitTimingTarget()
        throws(SurfaceSubmitConstraintError) -> SurfaceCommitTargetTime
    {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            return try SurfaceCommitTargetTime(seconds: 0, nanoseconds: 0)
        }

        var seconds = UInt64(timestamp.tv_sec)
        var nanoseconds = UInt32(timestamp.tv_nsec) + 16_666_667
        if nanoseconds > SurfaceCommitTargetTime.maximumNanosecondValue {
            seconds += 1
            nanoseconds -= SurfaceCommitTargetTime.maximumNanosecondValue + 1
        }

        return try SurfaceCommitTargetTime(seconds: seconds, nanoseconds: nanoseconds)
    }
}
