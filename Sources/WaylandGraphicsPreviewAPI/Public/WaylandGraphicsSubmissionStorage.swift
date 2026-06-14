import WaylandClient
import WaylandGPUPreview
import WaylandGraphicsCore
import WaylandRaw

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
package actor WaylandGraphicsWindowBackingStorage {
    let window: any WaylandGraphicsManagedWindow
    private let configuration: WaylandGraphicsConfiguration
    private let managedGPUBacking: (any WaylandGraphicsManagedGPUBacking)?
    private let externalBufferPresenter = GPUWindowPresenter()
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()
    private var nextExternalBufferSlotRawValue = 0

    package init(
        window backingWindow: any WaylandGraphicsManagedWindow,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath,
        configuration backingConfiguration: WaylandGraphicsConfiguration = .default,
        managedGPUBacking gpuBacking: (any WaylandGraphicsManagedGPUBacking)? = nil
    ) {
        window = backingWindow
        configuration = backingConfiguration
        managedGPUBacking = gpuBacking
        backingRuntimePath = initialRuntimePath
    }

    func runtimePath() throws -> WaylandGraphicsRuntimePath {
        try leaseState.requireNotClosed()
        return backingRuntimePath
    }

    package func nextFrame() async throws -> WaylandGraphicsFrameLease {
        try await nextFrame(afterWindowCheck: noGraphicsPreviewSubmissionHook)
    }

    func nextFrame(
        afterWindowCheck: @Sendable () async -> Void
    ) async throws -> WaylandGraphicsFrameLease {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        await afterWindowCheck()
        try leaseState.requireNotClosed()

        let geometry: SurfaceGeometry
        do {
            geometry = try await frameLeaseGeometry()
            try leaseState.requireNotClosed()
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
        let leaseID = try leaseState.issueLease()
        return WaylandGraphicsFrameLease(
            id: leaseID,
            size: geometry.bufferSize,
            runtimePath: backingRuntimePath,
            storage: self
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame
    ) async throws -> WaylandGraphicsFrameResult {
        try await submit(
            leaseID: leaseID,
            frame: frame,
            schedule: nil,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        schedule frameSchedule: WaylandGraphicsFrameSchedule
    ) async throws -> WaylandGraphicsFrameResult {
        try await submit(
            leaseID: leaseID,
            frame: frame,
            schedule: frameSchedule,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        schedule frameSchedule: WaylandGraphicsFrameSchedule? = nil,
        beforeSubmissionEffect: @Sendable () async throws -> Void,
        afterSubmissionEffect: @Sendable () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        try await prepareInitialConfigure(
            leaseID: leaseID,
            shouldPrepare: shouldAttemptManagedGPU
        )

        let geometry = try await submissionGeometry(for: leaseID)
        try effectiveConfiguration.validateManagedPreviewSupport(
            capabilities: backingRuntimePath.capabilities
        )
        try frame.validateManagedPreviewSupport(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            try await beforeSubmissionEffect()
            stage = .frameSubmission
            try await submitFrame(
                frame,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frame.metadata,
                configuration: effectiveConfiguration
            )
        } catch {
            if Self.isCommittedManagedGPUFrameFailure(error) {
                finishCommittedSubmissionFailure()
            } else {
                leaseState.failSubmission()
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    func submitSoftware(
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await submitSoftware(
            leaseID: leaseID,
            metadata: frameMetadata,
            schedule: nil,
            draw
        )
    }

    func submitSoftware(
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        schedule frameSchedule: WaylandGraphicsFrameSchedule?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        try rejectSoftwareSubmissionWhenExplicitRequired(configuration: effectiveConfiguration)

        let geometry = try await submissionGeometry(for: leaseID)
        try effectiveConfiguration.validateManagedPreviewSupport(
            capabilities: backingRuntimePath.capabilities
        )
        try frameMetadata.validateManagedPreviewSupport(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            stage = .frameSubmission
            try await submitSoftwareFrame(
                metadata: frameMetadata,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration,
                draw
            )
            stage = .submissionCompletion
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata,
                configuration: effectiveConfiguration
            )
        } catch {
            leaseState.failSubmission()
            if let drawError = WaylandGraphicsErrorMapper.callerDrawError(from: error) {
                throw drawError
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    func submitExternalBuffer(
        leaseID: WaylandGraphicsFrameLeaseID,
        descriptor externalDescriptor: consuming WaylandGraphicsExternalBufferDescriptor,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        synchronization externalSynchronization: WaylandGraphicsExternalSynchronization,
        schedule frameSchedule: WaylandGraphicsFrameSchedule?
    ) async throws -> WaylandGraphicsFrameResult {
        var descriptor = externalDescriptor
        let effectiveConfiguration = configuration.applying(schedule: frameSchedule)
        try closeDescriptorOnFailure(&descriptor) {
            try validateExternalSynchronization(
                externalSynchronization,
                configuration: effectiveConfiguration
            )
        }

        let geometry: SurfaceGeometry
        let operation: WaylandGraphicsFrameSubmissionOperation
        do {
            try leaseState.requireNotClosed()
            try await ensureWindowOpen()
            try await prepareInitialConfigure(
                leaseID: leaseID,
                shouldPrepare: shouldAttemptExternalBufferPresentation
            )
            geometry = try await submissionGeometry(for: leaseID)
            operation = try prepareExternalBufferSubmission(
                descriptor,
                leaseID: leaseID,
                metadata: frameMetadata,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
        } catch {
            closeExternalDescriptor(&descriptor)
            throw error
        }

        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            stage = .frameSubmission
            try await submitExternalBufferFrame(
                descriptor,
                metadata: frameMetadata,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
            stage = .submissionCompletion
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata,
                configuration: effectiveConfiguration
            )
        } catch {
            if Self.isCommittedExternalBufferFrameFailure(error) {
                finishCommittedSubmissionFailure()
            } else {
                leaseState.failSubmission()
            }
            throw graphicsError(
                for: externalGraphicsError(error), stage: stage, operation: operation)
        }
    }

    private func closeDescriptorOnFailure(
        _ descriptor: inout WaylandGraphicsExternalBufferDescriptor,
        _ body: () throws -> Void
    ) throws {
        do {
            try body()
        } catch {
            closeExternalDescriptor(&descriptor)
            throw error
        }
    }

    private func closeExternalDescriptor(
        _ descriptor: inout WaylandGraphicsExternalBufferDescriptor
    ) {
        do {
            try descriptor.closeFileDescriptors()
        } catch {
            _ = error
        }
    }

    private func submitExternalBufferFrame(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        let resolvedMetadata = try frameMetadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let importedBuffer = try await window.importGraphicsPreviewExternalBuffer(
            descriptor
        )
        try await presentExternalBuffer(
            importedBuffer,
            pacing: pacingSelection.constraint,
            metadata: resolvedMetadata.commitMetadata,
            requestPresentationFeedback: shouldRequestPresentationFeedback(
                configuration: effectiveConfiguration
            )
        )
        refreshRuntimePathFromExternalBuffer(backing: .active)
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
        applyExternalSynchronizationFallbackIfNeeded(configuration: effectiveConfiguration)
    }

    private func submissionGeometry(
        for leaseID: WaylandGraphicsFrameLeaseID
    ) async throws -> SurfaceGeometry {
        do {
            let operation = try leaseState.submissionOperation(leaseID: leaseID)
            let geometry = try await submissionGeometry(for: operation)
            try leaseState.requireSubmittable(leaseID: leaseID)
            return geometry
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func frameLeaseGeometry() async throws -> SurfaceGeometry {
        guard shouldAttemptManagedGPU, leaseState.hasSubmittedFrame else {
            return try await window.geometry
        }

        return try await window.prepareGraphicsPreviewPresentation(timeoutMilliseconds: 0)
    }

    private func submissionGeometry(
        for operation: WaylandGraphicsFrameSubmissionOperation
    ) async throws -> SurfaceGeometry {
        guard shouldAttemptManagedGPU, operation == .redraw else {
            return try await window.geometry
        }

        return try await window.prepareGraphicsPreviewPresentation(timeoutMilliseconds: 0)
    }

    private func prepareInitialConfigure(
        leaseID: WaylandGraphicsFrameLeaseID,
        shouldPrepare: Bool
    ) async throws {
        guard shouldPrepare else { return }

        let operation = try leaseState.submissionOperation(leaseID: leaseID)
        guard operation == .show else { return }

        do {
            _ = try await window.prepareGraphicsPreviewPresentation(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds
            )
            try leaseState.requireSubmittable(leaseID: leaseID)
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func ensureWindowOpen() async throws {
        do {
            let windowIsClosed = try await window.isClosed
            try leaseState.requireNotClosed()
            guard !windowIsClosed else {
                throw WaylandGraphicsError.windowClosed
            }
        } catch {
            throw graphicsError(for: error, stage: .windowStateCheck)
        }
    }

    private func graphicsError(
        for error: any Error,
        stage: WaylandGraphicsSubmissionStage,
        operation: WaylandGraphicsFrameSubmissionOperation? = nil
    ) -> WaylandGraphicsError {
        if leaseState.isClosed {
            return .backingClosed
        }
        if let committedFailure = error as? CommittedManagedGPUFrameFailure {
            return .unavailable(WaylandGraphicsUnavailableReason(committedFailure.failure))
        }
        if let graphicsError = error as? WaylandGraphicsError {
            return graphicsError
        }
        return WaylandGraphicsErrorMapper.mapSubmissionError(
            error,
            windowID: window.id,
            operation: operation?.graphicsSubmissionOperation,
            stage: stage
        )
    }

    func cancel(leaseID: WaylandGraphicsFrameLeaseID) {
        leaseState.cancel(leaseID: leaseID)
    }

    func close() async throws {
        guard !leaseState.isClosed else {
            return
        }

        leaseState.close()
        managedGPUBacking?.close()
        externalBufferPresenter.retireAll(reason: .windowClosed)
        await window.close()
    }

    private func submitFrame(
        _ frame: WaylandGraphicsSubmittedFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            try await submitClearFrame(
                clearFrame,
                operation: operation,
                geometry: geometry,
                configuration: effectiveConfiguration
            )
        }
    }

    private func submitClearFrame(
        _ frame: WaylandGraphicsClearFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        let color = frame.color.xrgb8888
        let resolvedMetadata = try frame.metadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let metadata = resolvedMetadata.commitMetadata
        let damage = try frame.metadata.surfaceDamageRegion()
        if shouldAttemptManagedGPU {
            do {
                _ = try await managedGPUBacking?.submitClearFrame(
                    WaylandGraphicsManagedGPUClearFrameSubmission(
                        color: frame.color.gpuClearColor,
                        metadata: metadata,
                        geometry: geometry,
                        synchronizationPolicy: effectiveConfiguration
                            .gpuSynchronizationPolicy,
                        pacingPolicy: effectiveConfiguration.gpuPacingPolicy,
                        requestPresentationFeedback: shouldRequestPresentationFeedback(
                            configuration: effectiveConfiguration
                        )
                    )
                )
                refreshRuntimePathFromManagedGPU(backing: .active)
                applyMetadataFallbacks(resolvedMetadata.fallbacks)
                return
            } catch {
                try handleManagedGPUFailure(error, configuration: effectiveConfiguration)
            }
        }

        try rejectSoftwareSubmissionWhenExplicitRequired(configuration: effectiveConfiguration)
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let submitConstraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: pacingSelection.constraint
        )
        try await submitSoftwareClearFrame(
            color: color,
            operation: operation,
            submitConstraints: submitConstraints,
            metadata: metadata,
            damage: damage,
            configuration: effectiveConfiguration
        )
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }

    // swiftlint:disable:next function_parameter_count
    private func submitSoftwareClearFrame(
        color: UInt32,
        operation: WaylandGraphicsFrameSubmissionOperation,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        damage: SurfaceDamageRegion?,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) async throws {
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        }
    }

    private func submitSoftwareFrame(
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        let resolvedMetadata = try frameMetadata.resolveManagedPreviewMetadata(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let metadata = resolvedMetadata.commitMetadata
        let damage = try frameMetadata.surfaceDamageRegion()
        let pacingSelection = try Self.softwarePacingSelection(
            policy: effectiveConfiguration.gpuPacingPolicy,
            capabilities: backingRuntimePath.capabilities,
            fifoBarrierPrimed: leaseState.hasSubmittedFrame
        )
        let submitConstraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: pacingSelection.constraint
        )
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage,
                draw
            )
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback(
                    configuration: effectiveConfiguration
                ),
                damage: damage,
                draw
            )
        }
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }
}

extension WaylandGraphicsWindowBackingStorage {
    private func shouldRequestPresentationFeedback(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) -> Bool {
        Self.shouldRequestPresentationFeedback(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities
        )
    }

    private var shouldAttemptManagedGPU: Bool {
        guard managedGPUBacking != nil else {
            return false
        }
        guard configuration.backingPreference == .managedGPU,
            configuration.fallbackPolicy != .forceSoftware
        else {
            return false
        }
        guard case .fallback = backingRuntimePath.backing else {
            return true
        }

        return false
    }

    private var shouldAttemptExternalBufferPresentation: Bool {
        configuration.backingPreference == .managedGPU
            && configuration.fallbackPolicy != .forceSoftware
    }

    private func handleManagedGPUFailure(
        _ error: ManagedGPUPreviewBackingError,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        if error.committedFrameWasPresented {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw CommittedManagedGPUFrameFailure(error)
        }

        guard effectiveConfiguration.synchronizationPolicy != .requireExplicit else {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw WaylandGraphicsError.unavailable(reason)
        }

        switch configuration.fallbackPolicy {
        case .preferGPUFallbackToSoftware:
            let reason = WaylandGraphicsFallbackReason(error.fallbackReason)
            updateBackingRuntimeStatus(.fallback(reason))
            backingRuntimePath = Self.runtimePath(
                backingRuntimePath,
                fallbackExplicitSyncIfNeeded: reason
            )
        case .requireGPU:
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw WaylandGraphicsError.unavailable(reason)
        case .forceSoftware:
            updateBackingRuntimeStatus(.fallback(.forcedSoftware))
        }
    }

    private func updateBackingRuntimeStatus(_ status: WaylandGraphicsRuntimeStatus) {
        guard !refreshRuntimePathFromManagedGPU(backing: status) else { return }
        backingRuntimePath = Self.runtimePath(backingRuntimePath, backing: status)
    }

    private func validateExternalSynchronization(
        _ synchronization: WaylandGraphicsExternalSynchronization,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        guard synchronization.acquire == nil,
            effectiveConfiguration.synchronizationPolicy != .requireExplicit
        else {
            let reason = WaylandGraphicsUnavailableReason.externalSynchronizationUnavailable
            backingRuntimePath = Self.runtimePath(
                backingRuntimePath,
                externalBufferFailure: reason
            )
            throw WaylandGraphicsError.unavailable(reason)
        }
    }

    private func validateExternalBufferDescriptor(
        _ descriptor: borrowing WaylandGraphicsExternalBufferDescriptor,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        guard backingRuntimePath.capabilities.dmabuf.isAvailable else {
            throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
        }
        guard effectiveConfiguration.backingPreference == .managedGPU,
            effectiveConfiguration.fallbackPolicy != .forceSoftware
        else {
            throw WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
        }
        guard descriptor.size == geometry.bufferSize else {
            throw WaylandGraphicsError.unavailable(.invalidExternalBufferDescriptor)
        }
    }

    private func prepareExternalBufferSubmission(
        _ descriptor: borrowing WaylandGraphicsExternalBufferDescriptor,
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        geometry: SurfaceGeometry,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws -> WaylandGraphicsFrameSubmissionOperation {
        try effectiveConfiguration.validateManagedPreviewSupport(
            capabilities: backingRuntimePath.capabilities
        )
        try validateExternalBufferDescriptor(
            descriptor,
            geometry: geometry,
            configuration: effectiveConfiguration
        )
        try frameMetadata.validateManagedPreviewSupport(
            configuration: effectiveConfiguration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        return try leaseState.prepareSubmission(leaseID: leaseID)
    }

    private func presentExternalBuffer(
        _ buffer: RawLinuxDmabufBuffer,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool
    ) async throws {
        var presenterOwnsBuffer = false
        do {
            let slotID: GBMBufferPoolSlotID
            if let reusableSlotID = externalBufferPresenter.availableSlotIDs.first {
                slotID = reusableSlotID
                try externalBufferPresenter.replaceAvailableBuffer(
                    buffer,
                    slotID: reusableSlotID
                )
                presenterOwnsBuffer = true
            } else {
                slotID = try nextExternalBufferSlotID()
                try externalBufferPresenter.installBuffer(buffer, slotID: slotID)
                presenterOwnsBuffer = true
            }

            _ = try await externalBufferPresenter.presentSlot(
                slotID,
                submit: { [window] surfaceBuffer, submitConstraints, commitMetadata in
                    try await window.presentGraphicsPreviewBuffer(
                        surfaceBuffer,
                        submitConstraints: submitConstraints,
                        metadata: commitMetadata,
                        requestPresentationFeedback: requestPresentationFeedback
                    )
                },
                synchronization: .implicit,
                pacing: pacing,
                metadata: metadata
            )
        } catch {
            if !presenterOwnsBuffer {
                buffer.destroy()
            }
            throw error
        }
    }

    private func nextExternalBufferSlotID() throws -> GBMBufferPoolSlotID {
        let slotID = try GBMBufferPoolSlotID(nextExternalBufferSlotRawValue)
        nextExternalBufferSlotRawValue += 1
        return slotID
    }

    private func refreshRuntimePathFromExternalBuffer(
        backing: WaylandGraphicsRuntimeStatus
    ) {
        backingRuntimePath = Self.runtimePath(
            backingRuntimePath,
            externalBufferBacking: backing
        )
    }

    private func applyExternalSynchronizationFallbackIfNeeded(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) {
        guard effectiveConfiguration.synchronizationPolicy == .preferExplicit else { return }

        backingRuntimePath = Self.runtimePath(
            backingRuntimePath,
            explicitSync: .fallback(.externalSynchronizationUnavailable)
        )
    }

    private func externalGraphicsError(_ error: any Error) -> any Error {
        if let graphicsError = error as? WaylandGraphicsError {
            return graphicsError
        }
        if let presenterError = error as? GPUWindowPresenterError {
            if let committed = presenterError.committedFrameFailure {
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(committed)
                )
            }
            switch presenterError {
            case .submitConstraints(let error):
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(GPUBackingFailure(error))
                )
            case .metadata(let error):
                return WaylandGraphicsError.unavailable(
                    WaylandGraphicsUnavailableReason(
                        GPUBackingFailure.metadataRequiredButUnavailable(error)
                    )
                )
            default:
                return WaylandGraphicsError.unavailable(.commitFailed)
            }
        }
        if error is RuntimeError {
            return WaylandGraphicsError.unavailable(.externalBufferImportFailed)
        }
        return error
    }

    private func finishCommittedSubmissionFailure() {
        do { try leaseState.finishSubmission() } catch { leaseState.failSubmission() }
    }

    private func rejectSoftwareSubmissionWhenExplicitRequired(
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) throws {
        let shouldReject =
            switch effectiveConfiguration.synchronizationPolicy {
            case .implicitOnly: false
            case .preferExplicit:
                Self.explicitSyncBlocksSoftwareFallback(
                    backingRuntimePath.explicitSync
                )
            case .requireExplicit: true
            }

        guard !shouldReject else {
            let reason = WaylandGraphicsUnavailableReason.managedGPUSubmissionUnavailable
            backingRuntimePath = Self.runtimePath(backingRuntimePath, backingUnavailable: reason)
            throw WaylandGraphicsError.unavailable(reason)
        }
    }

    private func applyMetadataFallbacks(_ fallbacks: WaylandGraphicsMetadataFallbacks) {
        if !fallbacks.isEmpty { backingRuntimePath = fallbacks.applying(to: backingRuntimePath) }
    }

    private func applyPacingSelection(_ selection: GPUFramePacingPolicySelection) {
        backingRuntimePath = Self.runtimePath(backingRuntimePath, pacingSelection: selection)
    }

    @discardableResult
    private func refreshRuntimePathFromManagedGPU(
        backing: WaylandGraphicsRuntimeStatus
    ) -> Bool {
        guard let managedGPUBacking,
            let capabilities = managedGPUBacking.surfaceCapabilities
        else {
            return false
        }

        backingRuntimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: managedGPUBacking.runtimePathSnapshot,
            capabilities: capabilities,
            backing: backing
        )
        return true
    }

    private func frameResult(
        operation: WaylandGraphicsFrameSubmissionOperation,
        size: PositivePixelSize,
        metadata: WaylandGraphicsFrameMetadata,
        configuration effectiveConfiguration: WaylandGraphicsConfiguration
    ) -> WaylandGraphicsFrameResult {
        WaylandGraphicsFrameResult(
            runtimePath: backingRuntimePath,
            operation: operation.graphicsSubmissionOperation,
            size: size,
            metadata: metadata,
            schedule: WaylandGraphicsFrameSchedule(
                configuration: effectiveConfiguration
            ),
            presentationFeedbackRequested: shouldRequestPresentationFeedback(
                configuration: effectiveConfiguration
            ),
            synchronizationPolicy: effectiveConfiguration.synchronizationPolicy,
            pacingPolicy: effectiveConfiguration.pacingPolicy
        )
    }
}

#if DEBUG
    extension WaylandGraphicsWindowBackingStorage {
        package func closeForTesting() async throws {
            try await close()
        }

        package func externalBufferSubmittedSlotRawValuesForTesting() -> [Int] {
            externalBufferPresenter.outstandingSubmittedSlotIDs.map(\.rawValue)
        }

        package func externalBufferAvailableSlotRawValuesForTesting() -> [Int] {
            externalBufferPresenter.availableSlotIDs.map(\.rawValue)
        }
    }
#endif
