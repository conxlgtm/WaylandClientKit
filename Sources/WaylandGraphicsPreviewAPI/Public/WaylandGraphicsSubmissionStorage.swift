import WaylandClient
import WaylandGPUPreview

// swiftlint:disable:next type_body_length
package actor WaylandGraphicsWindowBackingStorage {
    let window: any WaylandGraphicsManagedWindow
    private let configuration: WaylandGraphicsConfiguration
    private let managedGPUBacking: (any WaylandGraphicsManagedGPUBacking)?
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()

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
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        beforeSubmissionEffect: @Sendable () async throws -> Void,
        afterSubmissionEffect: @Sendable () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        try await prepareManagedGPUInitialConfigureIfNeeded(leaseID: leaseID)

        let geometry = try await submissionGeometry(for: leaseID)
        try frame.validateManagedPreviewSupport(
            configuration: configuration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            try await beforeSubmissionEffect()
            stage = .frameSubmission
            try await submitFrame(frame, operation: operation, geometry: geometry)
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frame.metadata
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
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        try rejectSoftwareSubmissionWhenExplicitRequired()

        let geometry = try await submissionGeometry(for: leaseID)
        try frameMetadata.validateManagedPreviewSupport(
            configuration: configuration,
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
                draw
            )
            stage = .submissionCompletion
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata
            )
        } catch {
            leaseState.failSubmission()
            if let drawError = WaylandGraphicsErrorMapper.callerDrawError(from: error) {
                throw drawError
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
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

    private func prepareManagedGPUInitialConfigureIfNeeded(
        leaseID: WaylandGraphicsFrameLeaseID
    ) async throws {
        guard shouldAttemptManagedGPU else { return }

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
        await window.close()
    }

    private func submitFrame(
        _ frame: WaylandGraphicsSubmittedFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry
    ) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            try await submitClearFrame(
                clearFrame,
                operation: operation,
                geometry: geometry
            )
        }
    }

    private func submitClearFrame(
        _ frame: WaylandGraphicsClearFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry
    ) async throws {
        let color = frame.color.xrgb8888
        let resolvedMetadata = try frame.metadata.resolveManagedPreviewMetadata(
            configuration: configuration,
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
                        synchronizationPolicy: configuration.gpuSynchronizationPolicy,
                        pacingPolicy: configuration.gpuPacingPolicy,
                        requestPresentationFeedback: shouldRequestPresentationFeedback
                    )
                )
                refreshRuntimePathFromManagedGPU(backing: .active)
                applyMetadataFallbacks(resolvedMetadata.fallbacks)
                return
            } catch {
                try handleManagedGPUFailure(error)
            }
        }

        try rejectSoftwareSubmissionWhenExplicitRequired()
        let pacingSelection = try Self.softwarePacingSelection(
            policy: configuration.gpuPacingPolicy,
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
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage
            ) { softwareFrame in
                clearSoftwareFrame(softwareFrame, color: color)
            }
        }
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }

    private func submitSoftwareFrame(
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        let resolvedMetadata = try frameMetadata.resolveManagedPreviewMetadata(
            configuration: configuration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let metadata = resolvedMetadata.commitMetadata
        let damage = try frameMetadata.surfaceDamageRegion()
        let pacingSelection = try Self.softwarePacingSelection(
            policy: configuration.gpuPacingPolicy,
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
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage,
                draw
            )
        case .redraw:
            try await window.redraw(
                submitConstraints: submitConstraints,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage,
                draw
            )
        }
        applyPacingSelection(pacingSelection)
        applyMetadataFallbacks(resolvedMetadata.fallbacks)
    }
}

extension WaylandGraphicsWindowBackingStorage {
    private var shouldRequestPresentationFeedback: Bool {
        Self.shouldRequestPresentationFeedback(
            configuration: configuration,
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

    private func handleManagedGPUFailure(
        _ error: ManagedGPUPreviewBackingError
    ) throws {
        if error.committedFrameWasPresented {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw CommittedManagedGPUFrameFailure(error)
        }

        guard configuration.synchronizationPolicy != .requireExplicit else {
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            updateBackingRuntimeStatus(.failed(reason))
            throw WaylandGraphicsError.unavailable(reason)
        }

        switch configuration.fallbackPolicy {
        case .preferGPUFallbackToSoftware:
            let reason = WaylandGraphicsFallbackReason(error.fallbackReason)
            updateBackingRuntimeStatus(.fallback(reason))
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

    private func finishCommittedSubmissionFailure() {
        do { try leaseState.finishSubmission() } catch { leaseState.failSubmission() }
    }

    private func rejectSoftwareSubmissionWhenExplicitRequired() throws {
        let shouldReject =
            switch configuration.synchronizationPolicy {
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
        metadata: WaylandGraphicsFrameMetadata
    ) -> WaylandGraphicsFrameResult {
        WaylandGraphicsFrameResult(
            runtimePath: backingRuntimePath,
            operation: operation.graphicsSubmissionOperation,
            size: size,
            metadata: metadata,
            presentationFeedbackRequested: shouldRequestPresentationFeedback,
            synchronizationPolicy: configuration.synchronizationPolicy,
            pacingPolicy: configuration.pacingPolicy
        )
    }
}
