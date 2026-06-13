// swiftlint:disable file_length
import Synchronization
import Testing

@testable import WaylandClient
@testable import WaylandGPUPreview
@testable import WaylandGraphicsCore
@testable import WaylandGraphicsPreview
@testable import WaylandRaw

@Suite
struct GPUWindowPresenterStateTests {
    @Test
    func leaseSubmitReleaseReturnsSlotToAvailable() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(lease, generation: 1)
        try state.markReleased(slotID)

        #expect(lease == GPUWindowPresentationLease(slotID: slotID))
        #expect(try state.lifecycle(for: slotID) == .available)
        #expect(state.installedSlotIDs == [slotID])
        #expect(state.outstandingSubmittedSlotIDs.isEmpty)
    }

    @Test
    func failedPresentationCanCancelLease() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.cancelLease(lease)

        #expect(try state.lifecycle(for: slotID) == .available)
    }

    @Test
    func submissionUsesWindowCommitGeneration() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(lease, generation: 42)

        #expect(try state.lifecycle(for: slotID) == .submitted(commitGeneration: 42))
        #expect(state.outstandingSubmittedSlotIDs == [slotID])
    }

    @Test
    func implicitSubmissionUsesBufferReleaseForReuse() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(
            lease,
            generation: 42,
            synchronization: .implicit
        )

        #expect(
            try state.submissionState(for: slotID)
                == .submittedImplicit(commitGeneration: 42)
        )

        try state.markReleased(slotID)

        #expect(try state.submissionState(for: slotID) == .available)
    }

    @Test
    func explicitSubmissionReusesSlotOnlyAfterReleasePointSignal() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        let releasePoint = syncPoint(timeline: 5, point: 8)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(
            lease,
            generation: 42,
            synchronization: .explicit(
                GPUSubmittedBufferSyncState(
                    slotID: slotID,
                    acquirePoint: syncPoint(timeline: 5, point: 6),
                    releasePoint: releasePoint
                )
            )
        )

        #expect(
            try state.submissionState(for: slotID)
                == .submittedExplicit(commitGeneration: 42, releasePoint: releasePoint)
        )

        #expect(try state.markReleased(slotID) == false)

        #expect(
            try state.submissionState(for: slotID)
                == .submittedExplicit(commitGeneration: 42, releasePoint: releasePoint)
        )

        #expect(try state.markReleased(slotID) == false)
        #expect(try state.markExplicitReleaseSignaled(slotID))
        #expect(try state.submissionState(for: slotID) == .available)
        #expect(try state.markReleased(slotID) == false)
        #expect(try state.markExplicitReleaseSignaled(slotID) == false)
    }

    @Test
    func synchronizationPolicyFallsBackOrFailsByMode() throws {
        let explicit = GPUExplicitSynchronization(
            acquireTimeline: GPUSyncTimeline(1),
            releaseTimeline: GPUSyncTimeline(2)
        )

        #expect(
            try GPUSynchronizationPolicy.preferExplicitFallbackToImplicit.selectMode(
                capability: .implicitOnly,
                explicitSynchronization: explicit
            ) == .implicit
        )
        #expect(
            try GPUSynchronizationPolicy.preferExplicitFallbackToImplicit.selectMode(
                capability: .explicitAvailable(version: 1),
                explicitSynchronization: explicit
            ) == .explicit(explicit)
        )
        #expect(
            try GPUSynchronizationPolicy.preferExplicitFallbackToImplicit.selectMode(
                capability: .explicitActive,
                explicitSynchronization: explicit
            ) == .explicit(explicit)
        )
        #expect(
            try GPUSynchronizationPolicy.requireExplicit.selectMode(
                capability: .explicitAvailable(version: 1),
                explicitSynchronization: explicit
            ) == .explicit(explicit)
        )
        #expect(throws: GPUSynchronizationPolicyError.explicitSynchronizationUnavailable) {
            _ = try GPUSynchronizationPolicy.requireExplicit.selectMode(
                capability: .implicitOnly,
                explicitSynchronization: explicit
            )
        }
        #expect(throws: GPUSynchronizationPolicyError.explicitSynchronizationNotConfigured) {
            _ = try GPUSynchronizationPolicy.requireExplicit.selectMode(
                capability: .explicitAvailable(version: 1),
                explicitSynchronization: nil
            )
        }
    }

    @Test
    func framePacingPolicySelectsConfiguredConstraintOrFallback() throws {
        let targetTime = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)

        #expect(
            GPUFramePacingPolicy.none.selectConstraint(
                capability: .fifoAndCommitTiming(fifo: 1, commitTiming: 1),
                commitTimingTarget: targetTime
            ) == GPUFramePacingPolicySelection(constraint: .none)
        )
        #expect(
            GPUFramePacingPolicy.preferFIFO.selectConstraint(
                capability: .fifo(version: 1),
                commitTimingTarget: targetTime
            ) == GPUFramePacingPolicySelection(constraint: .fifo(.waitBarrier))
        )
        let fifoFallback = GPUFramePacingPolicy.preferFIFO.selectConstraint(
            capability: .commitTiming(version: 1),
            commitTimingTarget: targetTime
        )
        let expectedFifoFallback = GPUFramePacingPolicySelection(
            constraint: .none,
            fallbackReason: .fifoUnavailable
        )
        #expect(fifoFallback == expectedFifoFallback)
        let commitTimingActive = GPUFramePacingPolicy.preferCommitTiming
            .selectConstraint(
                capability: .commitTiming(version: 1),
                commitTimingTarget: targetTime
            )
        let expectedCommitTimingActive = GPUFramePacingPolicySelection(
            constraint: .targetTime(targetTime)
        )
        #expect(commitTimingActive == expectedCommitTimingActive)
        let commitTimingFallback = GPUFramePacingPolicy.preferCommitTiming
            .selectConstraint(
                capability: .fifo(version: 1),
                commitTimingTarget: targetTime
            )
        let expectedCommitTimingFallback = GPUFramePacingPolicySelection(
            constraint: .none,
            fallbackReason: .commitTimingUnavailable
        )
        #expect(commitTimingFallback == expectedCommitTimingFallback)
    }

    @Test
    func presentationCorrelationMapsGenerationToSlot() throws {
        var correlation = GPUWindowPresentationCorrelation()
        let slotID = try GBMBufferPoolSlotID(0)
        let frame = try presentedFrame(slotID: slotID, generation: 77)

        correlation.record(frame)

        #expect(correlation.count == 1)
        #expect(!correlation.isEmpty)
        #expect(correlation.slotID(for: 77) == slotID)
        #expect(correlation.takeSlotID(for: 77) == slotID)
        #expect(correlation.slotID(for: 77) == nil)
        #expect(correlation.isEmpty)

        correlation.record(frame)

        correlation.remove(generation: 77)

        #expect(correlation.slotID(for: 77) == nil)

        let secondSlotID = try GBMBufferPoolSlotID(1)
        let secondFrame = try presentedFrame(slotID: secondSlotID, generation: 78)
        correlation.record(frame)
        correlation.record(secondFrame)

        correlation.remove(slotID: slotID)

        #expect(correlation.slotID(for: 77) == nil)
        #expect(correlation.slotID(for: 78) == secondSlotID)
    }

    @Test
    func presentationCorrelationConsumesTerminalFeedbackGenerations() throws {
        var correlation = GPUWindowPresentationCorrelation()
        let firstSlotID = try GBMBufferPoolSlotID(0)
        let secondSlotID = try GBMBufferPoolSlotID(1)

        correlation.record(try presentedFrame(slotID: firstSlotID, generation: 40))
        correlation.record(try presentedFrame(slotID: secondSlotID, generation: 41))

        #expect(correlation.takeSlotID(for: 40) == firstSlotID)
        #expect(correlation.takeSlotID(for: 40) == nil)
        #expect(correlation.slotID(for: 41) == secondSlotID)
        #expect(correlation.count == 1)

        correlation.remove(generation: 41)

        #expect(correlation.takeSlotID(for: 41) == nil)
        #expect(correlation.isEmpty)
    }

    @Test
    func presentationCorrelationClearsReleaseAndRetireCases() throws {
        var correlation = GPUWindowPresentationCorrelation()
        let firstSlotID = try GBMBufferPoolSlotID(0)
        let secondSlotID = try GBMBufferPoolSlotID(1)

        correlation.record(try presentedFrame(slotID: firstSlotID, generation: 50))
        correlation.record(try presentedFrame(slotID: secondSlotID, generation: 51))

        correlation.remove(slotID: firstSlotID)

        #expect(correlation.slotID(for: 50) == nil)
        #expect(correlation.slotID(for: 51) == secondSlotID)

        correlation.removeAll()

        #expect(correlation.isEmpty)
        #expect(correlation.takeSlotID(for: 51) == nil)
    }
}

@Suite
struct GPUWindowRuntimePathSnapshotTests {
    @Test
    func runtimePathSnapshotReportsSetupMilestones() {
        let capabilities = capabilitySnapshot(
            synchronization: .explicitAvailable(version: 1),
            pacing: .fifo(version: 1),
            contentType: .available
        )

        let discovered = GPURuntimePathSnapshot.afterCapabilityDiscovery(
            capabilities: capabilities
        )
        #expect(discovered.dmabuf == .advertised)
        #expect(discovered.gbm == .unavailable)
        #expect(discovered.egl == .unavailable)
        #expect(discovered.synchronization == .explicitAdvertised)
        #expect(discovered.pacing == .fifoAdvertised)

        let gbm = GPURuntimePathSnapshot.afterGBMDeviceSelection(
            capabilities: capabilities
        )
        #expect(gbm.gbm == .configured)
        #expect(gbm.egl == .unavailable)

        let egl = GPURuntimePathSnapshot.afterEGLTargetSetup(
            capabilities: capabilities
        )
        #expect(egl.gbm == .configured)
        #expect(egl.egl == .configured)

        let dmabuf = GPURuntimePathSnapshot.afterDmabufImportSetup(
            capabilities: capabilities
        )
        #expect(dmabuf.dmabuf == .active)
    }

    @Test
    func runtimePathSnapshotReportsFailureAndFallbackReasons() {
        let capabilities = capabilitySnapshot()
        let fallback = GPURuntimePathSnapshot.afterFallback(
            capabilities: capabilities,
            reason: .noCompatibleFormat
        )
        let failure = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilities,
            failure: .eglUnavailable
        )

        #expect(fallback.gbm == .fallback(.noCompatibleFormat))
        #expect(fallback.egl == .fallback(.noCompatibleFormat))
        #expect(failure.egl == .failed(.eglUnavailable))
    }

    @Test
    func runtimePathSnapshotReportsAdvertisedExplicitSyncNotConfigured() {
        let snapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(
                synchronization: .explicitAvailable(version: 1),
                pacing: .fifo(version: 1)
            ),
            synchronization: .implicit,
            pacing: .none
        )

        #expect(snapshot.dmabuf == .advertised)
        #expect(snapshot.gbm == .active)
        #expect(snapshot.egl == .configured)
        #expect(snapshot.synchronization == .explicitAdvertised)
        #expect(snapshot.pacing == .fifoAdvertised)
        #expect(snapshot.contentType == .unavailable)
        #expect(snapshot.alpha == .unavailable)
        #expect(snapshot.tearingControl == .unavailable)
        #expect(snapshot.colorRepresentation == .unavailable)
        #expect(snapshot.colorManagement == .unavailable)
        #expect(snapshot.presentationHint == nil)
    }

    @Test
    func runtimePathSnapshotReportsExplicitAndCommitTimingActive() throws {
        let snapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(
                synchronization: .explicitActive,
                pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
            ),
            synchronization: .explicit(
                GPUSubmittedBufferSyncState(
                    slotID: try GBMBufferPoolSlotID(0),
                    acquirePoint: syncPoint(timeline: 1, point: 1),
                    releasePoint: syncPoint(timeline: 1, point: 2)
                )
            ),
            pacing: .targetTime(
                try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            )
        )

        #expect(snapshot.synchronization == .explicitActive)
        #expect(snapshot.pacing == .commitTimingActive)
    }

    @Test
    func runtimePathSnapshotReportsAdvertisedMetadataCapabilities() {
        let snapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(
                contentType: .available,
                alphaModifier: .available,
                tearingControl: .available,
                colorRepresentation: supportedColorRepresentationCapability(),
                color: .available(version: 1)
            ),
            synchronization: .implicit,
            pacing: .none
        )

        #expect(snapshot.contentType == .advertised)
        #expect(snapshot.alpha == .advertised)
        #expect(snapshot.tearingControl == .advertised)
        #expect(snapshot.colorRepresentation == .advertised)
        #expect(snapshot.colorManagement == .advertised)
        #expect(snapshot.presentationHint == nil)
    }

    @Test
    func runtimePathSnapshotReportsRequestedMetadata() throws {
        let metadata = SurfaceCommitMetadata(
            contentType: .game,
            alpha: SurfaceAlphaMetadata(multiplier: .opaque),
            colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight),
            colorDescription: try SurfaceColorDescriptionReference(identity: 1),
            presentationHint: .async
        )
        let snapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(
                contentType: .available,
                alphaModifier: .available,
                tearingControl: .available,
                colorRepresentation: supportedColorRepresentationCapability(),
                color: .available(version: 1)
            ),
            synchronization: .implicit,
            pacing: .none,
            metadata: metadata
        )

        #expect(snapshot.contentType == .active)
        #expect(snapshot.alpha == .active)
        #expect(snapshot.tearingControl == .active)
        #expect(snapshot.colorRepresentation == .active)
        #expect(snapshot.colorManagement == .active)
        #expect(snapshot.presentationHint == .async)
    }

    @Test
    func runtimePathStatusesRepresentFailedAndFallbackPaths() {
        #expect(
            RuntimePathStatus.failed(.commitTimingUnavailable)
                == .failed(.commitTimingUnavailable)
        )
        #expect(
            GPUSynchronizationRuntimeStatus.explicitFailed(
                .explicitSynchronizationUnavailable
            )
                == .explicitFailed(.explicitSynchronizationUnavailable)
        )
        #expect(
            GPUFramePacingRuntimeStatus.fallback(.fifoUnavailable)
                == .fallback(.fifoUnavailable)
        )

        let fallbackSnapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(
                synchronization: .explicitAvailable(version: 1),
                pacing: .fifo(version: 1)
            ),
            synchronization: .implicit,
            pacing: .none
        )
        .markingSynchronizationFallback(.explicitSynchronizationNotConfigured)
        .markingPacingFallback(.commitTimingUnavailable)

        #expect(
            fallbackSnapshot.synchronization
                == .explicitFallback(.explicitSynchronizationNotConfigured)
        )
        #expect(fallbackSnapshot.pacing == .fallback(.commitTimingUnavailable))
    }

    @Test
    func publicRuntimePathMapsPacingFallbackToRequestedFeature() {
        let capabilities = capabilitySnapshot(
            pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
        )
        let fifoFallback = WaylandGraphicsRuntimePath(
            gpuSnapshot:
                GPURuntimePathSnapshot
                .afterPresentation(
                    capabilities: capabilities,
                    synchronization: .implicit,
                    pacing: .none
                )
                .markingPacingFallback(.fifoUnavailable),
            capabilities: capabilities,
            backing: .active
        )
        let commitTimingFallback = WaylandGraphicsRuntimePath(
            gpuSnapshot:
                GPURuntimePathSnapshot
                .afterPresentation(
                    capabilities: capabilities,
                    synchronization: .implicit,
                    pacing: .none
                )
                .markingPacingFallback(.commitTimingUnavailable),
            capabilities: capabilities,
            backing: .active
        )

        #expect(fifoFallback.pacing.fifo == .fallback(.fifoUnavailable))
        #expect(fifoFallback.pacing.commitTiming == .advertised)
        #expect(commitTimingFallback.pacing.fifo == .advertised)
        #expect(
            commitTimingFallback.pacing.commitTiming
                == .fallback(.commitTimingUnavailable)
        )
    }

    @Test
    func publicRuntimePathMapsPacingFailureToRequestedFeature() {
        let capabilities = capabilitySnapshot(
            pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
        )
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilities,
            failure: .commitTimingRejected
        )
        let runtimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: snapshot,
            capabilities: capabilities,
            backing: .failed(.commitTimingRejected)
        )

        #expect(runtimePath.pacing.fifo == .advertised)
        #expect(runtimePath.pacing.commitTiming == .failed(.commitTimingRejected))
    }

    @Test
    func runtimePathReportsCommitTimingUnavailableForTargetTimeFailure() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(pacing: .fifo(version: 1)),
            failure: .commitTimingRequiredButUnavailable
        )

        #expect(snapshot.pacing == .failed(.commitTimingUnavailable))
    }

    @Test
    func runtimePathReportsCommitTimingRejectedForTimestampFailure() {
        #expect(
            GPUBackingFailure(.commitTimestampAlreadyExists)
                == .commitTimingRejected
        )
        #expect(
            GPUBackingFailure(.invalidCommitTimestamp)
                == .commitTimingRejected
        )

        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(pacing: .commitTiming(version: 1)),
            failure: GPUBackingFailure(.invalidCommitTimestamp)
        )

        #expect(snapshot.pacing == .failed(.commitTimingRejected))
        #expect(snapshot.synchronization != .explicitFailed(.commitTimingRejected))
    }
}

@Suite
struct GPUWindowRuntimePathExplicitSyncFailureTests {
    @Test
    func syncobjErrorsMapToExplicitSyncFailures() {
        #expect(
            ManagedGPUPreviewBackingError.backingFailure(
                for: .syncobjCreationFailed(errno: 1)
            ) == .explicitSyncSetupFailed
        )
        #expect(
            ManagedGPUPreviewBackingError.backingFailure(
                for: .syncobjFileDescriptorExportFailed(errno: 2)
            ) == .explicitSyncSetupFailed
        )
        #expect(
            ManagedGPUPreviewBackingError.backingFailure(
                for: .syncobjTimelineSignalFailed(point: 3, errno: 4)
            ) == .explicitSyncSubmissionFailed
        )
        #expect(
            ManagedGPUPreviewBackingError.backingFailure(
                for: .syncobjTimelineWaitFailed(point: 5, errno: 6)
            ) == .explicitSyncReleaseFailed
        )
    }

    @Test
    func runtimePathReportsExplicitSyncFailuresOnExplicitSyncComponent() {
        let capabilities = capabilitySnapshot(synchronization: .explicitAvailable(version: 1))
        let setupFallback = WaylandGraphicsRuntimePath(
            gpuSnapshot:
                GPURuntimePathSnapshot
                .afterPresentation(
                    capabilities: capabilities,
                    synchronization: .implicit,
                    pacing: .none
                )
                .markingSynchronizationFallback(.explicitSynchronizationSetupFailed),
            capabilities: capabilities,
            backing: .active
        )
        let releaseFailure = WaylandGraphicsRuntimePath(
            gpuSnapshot: .afterFailure(
                capabilities: capabilities,
                failure: .explicitSyncReleaseFailed
            ),
            capabilities: capabilities,
            backing: .failed(.explicitSyncReleaseFailed)
        )

        #expect(
            setupFallback.explicitSync == .fallback(.explicitSyncSetupFailed)
        )
        #expect(
            releaseFailure.explicitSync == .failed(.explicitSyncReleaseFailed)
        )
        #expect(releaseFailure.gbm == .unavailable)
    }
}

@Suite
struct GPUWindowRuntimePathMetadataFailureTests {
    @Test
    func runtimePathReportsCompositorRejectedBuffer() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(),
            failure: .compositorRejectedBuffer
        )

        #expect(snapshot.dmabuf == .failed(.compositorRejectedBuffer))
    }

    @Test
    func runtimePathFailurePreservesCompletedSetupStages() {
        let capabilities = capabilitySnapshot()
        let snapshot =
            GPURuntimePathSnapshot
            .afterEGLTargetSetup(capabilities: capabilities)
            .markingFailure(.compositorRejectedBuffer)
        let fallbackPath = WaylandGraphicsRuntimePath(
            gpuSnapshot: snapshot,
            capabilities: capabilities,
            backing: .fallback(.compositorRejectedBuffer)
        )

        #expect(snapshot.renderNode == .active)
        #expect(snapshot.gbm == .configured)
        #expect(snapshot.egl == .configured)
        #expect(snapshot.dmabufImport == .failed(.compositorRejectedBuffer))
        #expect(fallbackPath.backing == .fallback(.compositorRejectedBuffer))
        #expect(fallbackPath.gbm == .configured)
        #expect(fallbackPath.egl == .configured)
        #expect(fallbackPath.dmabufImport == .failed(.compositorRejectedBuffer))
    }

    @Test
    func runtimePathReportsCommitFailure() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(),
            failure: .commitFailed
        )

        #expect(snapshot.dmabuf == .failed(.commitFailed))
    }

    @Test
    func runtimePathReportsContentTypeUnavailableForContentTypeRequirement() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(contentType: .unavailable),
            failure: .metadataRequiredButUnavailable(.contentTypeUnavailable)
        )
        let runtimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: snapshot,
            capabilities: capabilitySnapshot(contentType: .unavailable),
            backing: .failed(.contentTypeUnavailable)
        )

        #expect(snapshot.contentType == .failed(.contentTypeUnavailable))
        #expect(runtimePath.metadata.contentType == .failed(.contentTypeUnavailable))
    }

    @Test
    func runtimePathReportsAlphaModifierUnavailableForAlphaRequirement() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(alphaModifier: .unavailable),
            failure: .metadataRequiredButUnavailable(.alphaModifierUnavailable)
        )

        #expect(snapshot.alpha == .failed(.alphaModifierUnavailable))
    }

    @Test
    func runtimePathReportsTearingControlUnavailableForPresentationHintRequirement() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(tearingControl: .unavailable),
            failure: .metadataRequiredButUnavailable(.tearingControlUnavailable)
        )
        let runtimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: snapshot,
            capabilities: capabilitySnapshot(tearingControl: .unavailable),
            backing: .failed(.presentationHintUnavailable)
        )

        #expect(snapshot.tearingControl == .failed(.presentationHintUnavailable))
        #expect(
            runtimePath.metadata.tearingControl
                == .failed(.presentationHintUnavailable)
        )
    }

    @Test
    func runtimePathReportsColorManagementUnavailableForColorDescriptionRequirement() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(color: .unavailable),
            failure: .metadataRequiredButUnavailable(.colorUnavailable)
        )

        #expect(snapshot.colorManagement == .failed(.colorManagementUnavailable))
    }
}

@Suite
struct GPUWindowRuntimePathFailureTests {
    @Test
    func runtimePathReportsGBMAllocationFailure() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(),
            failure: .gbmAllocationFailed
        )

        #expect(snapshot.gbm == .failed(.gbmAllocationFailed))
        #expect(snapshot.egl == .unavailable)
    }

    @Test
    func runtimePathReportsNoRenderNodeFailure() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(),
            failure: .noRenderNode
        )

        #expect(snapshot.renderNode == .failed(.noRenderNode))
        #expect(snapshot.gbm == .failed(.noRenderNode))
        #expect(snapshot.dmabuf == .advertised)
    }

    @Test
    func runtimePathReportsEGLFailureAfterDmabufDiscovery() {
        let snapshot = GPURuntimePathSnapshot.afterFailure(
            capabilities: capabilitySnapshot(),
            failure: .eglUnavailable
        )

        #expect(snapshot.egl == .failed(.eglUnavailable))
        #expect(snapshot.gbm == .unavailable)
        #expect(snapshot.dmabuf == .advertised)
    }

    @Test
    func publicRuntimePathPreservesSpecificGPUFailureStages() {
        let capabilities = capabilitySnapshot()
        let importFailure = WaylandGraphicsRuntimePath(
            gpuSnapshot: .afterFailure(
                capabilities: capabilities,
                failure: .compositorRejectedBuffer
            ),
            capabilities: capabilities,
            backing: .failed(.compositorRejectedBuffer)
        )
        let commitTimingFailure = WaylandGraphicsRuntimePath(
            gpuSnapshot: .afterFailure(
                capabilities: capabilities,
                failure: .commitTimingRejected
            ),
            capabilities: capabilities,
            backing: .failed(.commitTimingRejected)
        )
        let commitFailure = WaylandGraphicsRuntimePath(
            gpuSnapshot: .afterFailure(
                capabilities: capabilities,
                failure: .commitFailed
            ),
            capabilities: capabilities,
            backing: .failed(.commitFailed)
        )

        #expect(importFailure.dmabufImport == .failed(.compositorRejectedBuffer))
        #expect(importFailure.backing == .failed(.compositorRejectedBuffer))
        #expect(commitTimingFailure.pacing.commitTiming == .failed(.commitTimingRejected))
        #expect(commitTimingFailure.backing == .failed(.commitTimingRejected))
        #expect(commitFailure.bufferLifecycle == .failed(.commitFailed))
        #expect(commitFailure.backing == .failed(.commitFailed))
    }

    @Test
    func managedBackingFallbackReasonPreservesCommitFailures() {
        #expect(
            ManagedGPUPreviewBackingError.setup(.commitTimingRejected)
                .fallbackReason == .commitTimingRejected
        )
        #expect(
            ManagedGPUPreviewBackingError.setup(.commitFailed)
                .fallbackReason == .commitFailed
        )
        #expect(
            ManagedGPUPreviewBackingError.setup(.presentationTrackingFailed)
                .fallbackReason == .presentationTrackingFailed
        )
        #expect(
            WaylandGraphicsFallbackReason(
                ManagedGPUPreviewBackingError.setup(.commitFailed).fallbackReason
            ) == .commitFailed
        )
    }
}

@Suite
struct GPUWindowBackingPolicyTests {
    @Test
    func fallbackPolicyDistinguishesFallbackFromUnavailable() {
        let unavailable = capabilitySnapshot(dmabuf: .unavailable)

        #expect(
            GPUFallbackPolicy.preferGPUFallbackToSHM.decide(
                capabilities: unavailable
            ) == .shm(.dmabufUnavailable)
        )
        #expect(
            GPUFallbackPolicy.requireGPU.decide(capabilities: unavailable)
                == .unavailable(.dmabufUnavailable)
        )
        #expect(
            GPUFallbackPolicy.forceSHM.decide(capabilities: capabilitySnapshot())
                == .shm(.policyForcedSHM)
        )
    }

    @Test
    func backingPolicyRejectsRequestedColorDescriptionWhenColorManagementUnavailable() throws {
        let requirements = GPUBackingRequirements(
            metadata: SurfaceCommitMetadata(
                colorDescription: try SurfaceColorDescriptionReference(identity: 1)
            )
        )
        let capabilities = capabilitySnapshot(contentType: .available, color: .unavailable)

        #expect(
            GPUFallbackPolicy.requireGPU.decide(
                capabilities: capabilities,
                requirements: requirements
            ) == .unavailable(.metadataRequiredButUnavailable(.colorUnavailable))
        )
    }

    @Test
    func backingPolicyRejectsTargetTimeWhenCommitTimingUnavailable() throws {
        let requirements = GPUBackingRequirements(
            pacing: .targetTime(
                try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            )
        )

        #expect(
            GPUFallbackPolicy.requireGPU.decide(
                capabilities: capabilitySnapshot(pacing: .fifo(version: 1)),
                requirements: requirements
            ) == .unavailable(.commitTimingRequiredButUnavailable)
        )
    }

    @Test
    func backingPolicyRejectsFifoWhenFifoUnavailable() {
        let requirements = GPUBackingRequirements(pacing: .fifo(.setBarrier))

        #expect(
            GPUFallbackPolicy.requireGPU.decide(
                capabilities: capabilitySnapshot(pacing: .commitTiming(version: 1)),
                requirements: requirements
            ) == .unavailable(.fifoRequiredButUnavailable)
        )
    }

    @Test
    func fifoAndTargetTimeReportsFirstMissingPacingProtocol() throws {
        let requirements = GPUBackingRequirements(
            pacing: .fifoAndTargetTime(
                .waitBarrier,
                try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            )
        )

        #expect(
            GPUFallbackPolicy.requireGPU.decide(
                capabilities: capabilitySnapshot(pacing: .unavailable),
                requirements: requirements
            ) == .unavailable(.fifoRequiredButUnavailable)
        )
    }

    @Test
    func backingPolicyAcceptsContentTypeWhenOnlyContentTypeIsRequested() {
        let decision = GPUFallbackPolicy.requireGPU.decide(
            capabilities: capabilitySnapshot(contentType: .available),
            requirements: GPUBackingRequirements(
                metadata: SurfaceCommitMetadata(contentType: .game)
            )
        )

        guard case .gpu(let state) = decision else {
            Issue.record("Expected GPU backing decision, got \(decision)")
            return
        }

        #expect(state.lifecycle == .configuring)
    }

    @Test
    func backingPolicyRejectsPresentationHintWhenTearingControlUnavailable() {
        let requirements = GPUBackingRequirements(
            metadata: SurfaceCommitMetadata(presentationHint: .async)
        )
        let decision = GPUFallbackPolicy.requireGPU.decide(
            capabilities: capabilitySnapshot(tearingControl: .unavailable),
            requirements: requirements
        )
        let expected = GPUBackingDecision.unavailable(
            .metadataRequiredButUnavailable(.tearingControlUnavailable)
        )

        #expect(decision == expected)
    }

    @Test
    func backingPolicyPreservesRequireGPUVsFallbackPolicyForMetadataFailure() {
        let requirements = GPUBackingRequirements(
            metadata: SurfaceCommitMetadata(contentType: .game)
        )
        let capabilities = capabilitySnapshot(contentType: .unavailable)

        #expect(
            GPUFallbackPolicy.requireGPU.decide(
                capabilities: capabilities,
                requirements: requirements
            ) == .unavailable(.metadataRequiredButUnavailable(.contentTypeUnavailable))
        )
        #expect(
            GPUFallbackPolicy.preferGPUFallbackToSHM.decide(
                capabilities: capabilities,
                requirements: requirements
            ) == .shm(.metadataRequiredButUnavailable(.contentTypeUnavailable))
        )
    }
}

@Suite
struct GPUWindowBackingStateTests {
    @Test
    func backingStateRecordsSuccessFailureFallbackAndRetire() throws {
        let capabilities = capabilitySnapshot()
        let frame = try presentedFrame(
            slotID: try GBMBufferPoolSlotID(0),
            generation: 10
        )
        var state = GPUWindowBackingState.unconfigured

        state.recordCapabilities(capabilities)
        #expect(state.lifecycle == .configuring)
        #expect(state.runtimePath.dmabuf == .advertised)

        state.markReady(
            runtimePath: .afterPresentation(
                capabilities: capabilities,
                synchronization: .implicit,
                pacing: .none
            ),
            capabilities: capabilities,
            bufferPool: .ready(installedSlots: 2, availableSlots: 1, submittedSlots: 1),
            frame: frame
        )
        #expect(state.lifecycle == .ready)
        #expect(state.lastSubmittedFrame == frame)

        state.markFallback(.noCompatibleFormat, capabilities: capabilities)
        #expect(state.lifecycle == .fallbackToSHM(.noCompatibleFormat))
        #expect(state.diagnostics.last?.payload == .fallbackSelected(.noCompatibleFormat))

        state.markFailed(.eglUnavailable, operation: .eglSetup)
        #expect(state.lifecycle == .failed(.eglUnavailable))
        #expect(state.diagnostics.last?.payload == .failure(.eglUnavailable))

        state.markRetired()
        #expect(state.lifecycle == .retired)
        #expect(state.runtimePath == .empty)
        #expect(state.bufferPool == .retired)
        #expect(state.lastSubmittedFrame == nil)
    }

    @Test
    func backingStateRetireClearsRuntimePath() throws {
        let capabilities = capabilitySnapshot()
        var state = GPUWindowBackingState.unconfigured
        state.markReady(
            runtimePath: .afterPresentation(
                capabilities: capabilities,
                synchronization: .implicit,
                pacing: .none
            ),
            capabilities: capabilities,
            bufferPool: .ready(installedSlots: 1, availableSlots: 0, submittedSlots: 1),
            frame: try presentedFrame(
                slotID: try GBMBufferPoolSlotID(0),
                generation: 11
            )
        )
        #expect(state.runtimePath.gbm == .active)

        state.markRetired()

        #expect(state.lifecycle == .retired)
        #expect(state.runtimePath == .empty)
        #expect(state.bufferPool == .retired)
        #expect(state.lastSubmittedFrame == nil)
    }

    @Test
    func invalidationReportsCapabilityGeometryAndMetadataChanges() throws {
        let oldSnapshot = capabilitySnapshot()
        let newSnapshot = capabilitySnapshot(
            synchronization: .explicitAvailable(version: 1),
            contentType: .available,
            color: .available(version: 1)
        )
        let oldGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 10, height: 10),
            scale: .one
        )
        let newGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 20, height: 10),
            scale: try SurfaceScale(numerator: 2, denominator: 1)
        )
        let invalidations = GPUBackingInvalidation.changes(
            oldSnapshot: oldSnapshot,
            newSnapshot: newSnapshot,
            oldGeometry: oldGeometry,
            newGeometry: newGeometry,
            oldSynchronization: .implicitOnly,
            newSynchronization: .explicitAvailable(version: 1),
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(contentType: .game),
            oldPacing: .unavailable,
            newPacing: .fifo(version: 1)
        ).map(\.reason)

        #expect(invalidations.contains(.logicalSizeChanged))
        #expect(invalidations.contains(.bufferScaleChanged))
        #expect(invalidations.contains(.synchronizationModeChanged))
        #expect(invalidations.contains(.colorMetadataChanged))
        #expect(invalidations.contains(.presentationModeChanged))
    }

    @Test
    func contentTypeMetadataChangeInvalidatesBacking() {
        let reasons = invalidationReasons(
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(contentType: .game)
        )

        #expect(reasons == [.colorMetadataChanged])
    }

    @Test
    func alphaMetadataChangeInvalidatesBacking() {
        let reasons = invalidationReasons(
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(
                alpha: SurfaceAlphaMetadata(multiplier: .transparent)
            )
        )

        #expect(reasons == [.colorMetadataChanged])
    }

    @Test
    func colorRepresentationMetadataChangeInvalidatesBacking() {
        let reasons = invalidationReasons(
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(
                colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
            )
        )

        #expect(reasons == [.colorMetadataChanged])
    }

    @Test
    func colorDescriptionMetadataChangeInvalidatesBacking() throws {
        let reasons = invalidationReasons(
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(
                colorDescription: try SurfaceColorDescriptionReference(identity: 1)
            )
        )

        #expect(reasons == [.colorMetadataChanged])
    }

    @Test
    func presentationHintChangeInvalidatesPresentationModeOnly() {
        let reasons = invalidationReasons(
            oldMetadata: .default,
            newMetadata: SurfaceCommitMetadata(presentationHint: .async)
        )

        #expect(reasons == [.presentationModeChanged])
    }
}

@Suite
struct GPUWindowPresenterLifecycleTests {
    @Test
    func retiredStateRejectsNewPresentationWork() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        state.retireAll(reason: .windowClosed)

        #expect(state.isRetired)
        #expect(state.installedSlotIDs.isEmpty)
        #expect(state.outstandingSubmittedSlotIDs.isEmpty)
        #expect(throws: GPUWindowPresenterStateError.retired(.windowClosed)) {
            try state.installSlot(slotID)
        }
        #expect(throws: GPUWindowPresenterStateError.retired(.windowClosed)) {
            _ = try state.leaseNext()
        }
    }

    @Test
    func releaseAfterRetireIsIgnored() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)
        let lease = try state.leaseNext()
        try state.markSubmitted(lease, generation: 7)

        state.retireAll(reason: .windowClosed)
        try state.markReleased(slotID)

        #expect(state.isRetired)
    }

    @Test
    func explicitReleaseAfterRetireIsIgnored() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)
        let lease = try state.leaseNext()
        let releasePoint = syncPoint(timeline: 4, point: 9)
        try state.markSubmitted(
            lease,
            generation: 8,
            synchronization: .explicit(
                GPUSubmittedBufferSyncState(
                    slotID: slotID,
                    acquirePoint: nil,
                    releasePoint: releasePoint
                )
            )
        )

        state.retireAll(reason: .windowClosed)

        #expect(try state.markExplicitReleaseSignaled(slotID) == false)
        #expect(try state.submissionState(for: slotID) == .retired)
        #expect(state.bufferPoolReadiness == .retired)
    }

    @Test
    func presenterRetireAllDestroysInstalledBuffersOnce() throws {
        let presenter = GPUWindowPresenter()
        let firstSlotID = try GBMBufferPoolSlotID(0)
        let secondSlotID = try GBMBufferPoolSlotID(1)
        let firstBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let secondBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(firstBuffer, slotID: firstSlotID)
        try presenter.installBuffer(secondBuffer, slotID: secondSlotID)
        #expect(
            presenter.backingStateSnapshot.bufferPool
                == .ready(installedSlots: 2, availableSlots: 2, submittedSlots: 0)
        )
        presenter.retireAll(reason: .windowClosed)

        #expect(firstBuffer.destroyCallCount == 1)
        #expect(secondBuffer.destroyCallCount == 1)
        #expect(presenter.installedSlotIDs.isEmpty)
        #expect(presenter.outstandingSubmittedSlotIDs.isEmpty)
        #expect(presenter.backingStateSnapshot.lifecycle == .retired)

        presenter.retireAll(reason: .windowClosed)

        #expect(firstBuffer.destroyCallCount == 1)
        #expect(secondBuffer.destroyCallCount == 1)
    }

    @Test
    func presenterRetireAllClearsReleaseObserverSoLateReleaseIsIgnored() throws {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let buffer = try FakePresenterBuffer(pointer: 0x1001)

        try presenter.installBuffer(buffer, slotID: slotID)
        presenter.retireAll(reason: .windowClosed)
        buffer.triggerRelease()

        #expect(buffer.destroyCallCount == 1)
        #expect(!buffer.hasReleaseObserver)
        #expect(presenter.releaseFailuresSnapshot.isEmpty)
    }

    @Test
    func presenterRetireAllClearsPresentationCorrelationSoLateFeedbackIsIgnored()
        throws
    {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let buffer = try FakePresenterBuffer(pointer: 0x1001)

        try presenter.installBuffer(buffer, slotID: slotID)
        let lease = try presenter.leaseNextForTesting()
        let frame = try presenter.recordPresentedFrameForTesting(
            previewPresentationResult(generation: 99),
            lease: lease
        )

        #expect(presenter.backingStateSnapshot.lastSubmittedFrame == frame)

        presenter.retireAll(reason: .windowClosed)

        #expect(
            presenter.correlatedSlotID(
                forPresentationGeneration: frame.generation
            ) == nil
        )
        #expect(presenter.backingStateSnapshot.lastSubmittedFrame == nil)
        #expect(presenter.releaseFailuresSnapshot.isEmpty)
    }

    @Test
    func presenterRejectsInstallAfterRetire() throws {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)

        presenter.retireAll(reason: .windowClosed)

        do {
            try presenter.installBuffer(try FakePresenterBuffer(pointer: 0x1001), slotID: slotID)
            Issue.record("Expected retired presenter to reject buffer installation")
        } catch GPUWindowPresenterError.state(.retired(.windowClosed)) {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func presenterRejectsDuplicateInstall() throws {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)

        try presenter.installBuffer(try FakePresenterBuffer(pointer: 0x1001), slotID: slotID)

        do {
            try presenter.installBuffer(try FakePresenterBuffer(pointer: 0x1002), slotID: slotID)
            Issue.record("Expected duplicate slot installation to fail")
        } catch GPUWindowPresenterError.state(.pool(.duplicateSlot(let duplicateSlotID))) {
            #expect(duplicateSlotID == slotID)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func presenterFailureAfterSuccessReportsFailedRuntimePath() {
        let presenter = GPUWindowPresenter()
        let capabilities = capabilitySnapshot()

        presenter.markReadyForTesting(capabilities: capabilities)
        #expect(presenter.backingStateSnapshot.lifecycle == .ready)
        #expect(presenter.runtimePathSnapshot.gbm == .active)

        presenter.markFailureForTesting(.commitFailed, operation: .surfaceCommit)
        let snapshot = presenter.backingStateSnapshot

        #expect(snapshot.lifecycle == .failed(.commitFailed))
        #expect(snapshot.runtimePath.dmabuf == .failed(.commitFailed))
        #expect(snapshot.runtimePath.gbm == .unavailable)
        #expect(presenter.runtimePathSnapshot == snapshot.runtimePath)
    }

    @Test
    func presenterPreservesPostCommitStateErrorWithoutCancelingLease() throws {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let buffer = try FakePresenterBuffer(pointer: 0x1001)
        try presenter.installBuffer(buffer, slotID: slotID)
        let lease = try presenter.leaseNextForTesting()
        try presenter.cancelLeaseForTesting(lease)

        do {
            _ = try presenter.recordPresentedFrameForTesting(
                try previewPresentationResult(),
                lease: lease
            )
            Issue.record("Expected invalid generation to fail presentation recording")
        } catch GPUWindowPresenterError.state(
            .pool(.slotNotLeased(let failedSlotID, actual: .available))
        ) {
            #expect(failedSlotID == slotID)
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(
            presenter.backingStateSnapshot.bufferPool
                == .exhausted(installedSlots: 1, submittedSlots: 1)
        )
        #expect(
            presenter.backingStateSnapshot.lifecycle
                == .failed(.presentationTrackingFailed)
        )
        #expect(
            presenter.backingStateSnapshot.diagnostics.last?.payload
                == .failure(.presentationTrackingFailed)
        )

        buffer.triggerRelease()

        #expect(
            presenter.backingStateSnapshot.bufferPool
                == .ready(installedSlots: 1, availableSlots: 1, submittedSlots: 0)
        )
        #expect(presenter.releaseFailuresSnapshot.isEmpty)
    }

    @Test
    func previewBufferPresentationResultRejectsZeroGeneration() throws {
        let commitPlan = try surfaceCommitPlan()

        #expect(throws: PreviewBufferPresentationResultError.invalidGeneration(0)) {
            try PreviewBufferPresentationResult(
                generation: 0,
                commitPlan: commitPlan,
                capabilities: capabilitySnapshot()
            )
        }
    }

    @Test
    func presenterRetireAfterReadyClearsBackingRuntimePath() {
        let presenter = GPUWindowPresenter()
        presenter.markReadyForTesting(capabilities: capabilitySnapshot())
        #expect(presenter.backingStateSnapshot.runtimePath.gbm == .active)

        presenter.retireAll(reason: .windowClosed)
        let snapshot = presenter.backingStateSnapshot

        #expect(snapshot.lifecycle == .retired)
        #expect(snapshot.runtimePath == .empty)
        #expect(presenter.runtimePathSnapshot == .empty)
    }

    @Test
    func retiredBackingSnapshotMatchesPresenterRuntimePath() {
        let presenter = GPUWindowPresenter()
        presenter.markReadyForTesting(capabilities: capabilitySnapshot())

        presenter.retireAll(reason: .windowClosed)

        #expect(presenter.backingStateSnapshot.runtimePath == presenter.runtimePathSnapshot)
    }

    @Test
    func presenterDeinitRetiresInstalledBuffers() throws {
        var presenter: GPUWindowPresenter? = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let buffer = try FakePresenterBuffer(pointer: 0x1001)

        try presenter?.installBuffer(buffer, slotID: slotID)
        presenter = nil
        buffer.triggerRelease()

        #expect(buffer.destroyCallCount == 1)
        #expect(!buffer.hasReleaseObserver)
    }
}

@Suite
struct GPUWindowPresenterBufferReuseTests {
    @Test
    func presenterRetireAvailableBuffersLeavesSubmittedBuffers() async throws {
        let presenter = GPUWindowPresenter()
        let submittedSlotID = try GBMBufferPoolSlotID(0)
        let availableSlotID = try GBMBufferPoolSlotID(1)
        let submittedBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let availableBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(submittedBuffer, slotID: submittedSlotID)
        try presenter.installBuffer(availableBuffer, slotID: availableSlotID)
        _ = try await presenter.presentSlot(
            submittedSlotID,
            submit: { _, _, _ in
                try previewPresentationResult(generation: 50)
            },
            synchronization: .implicit,
            pacing: .none
        )

        let retiredSlotIDs = try presenter.retireAvailableBuffers()

        #expect(retiredSlotIDs == [availableSlotID])
        #expect(submittedBuffer.destroyCallCount == 0)
        #expect(availableBuffer.destroyCallCount == 1)
        #expect(presenter.installedSlotIDs == [submittedSlotID])
        #expect(presenter.outstandingSubmittedSlotIDs == [submittedSlotID])
    }

    @Test
    func presenterReplacesReleasedBufferInSameSlot() async throws {
        let presenter = GPUWindowPresenter()
        let recorder = SubmittedPointerRecorder()
        let slotID = try GBMBufferPoolSlotID(0)
        let firstBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let replacementBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(firstBuffer, slotID: slotID)
        _ = try await presenter.presentSlot(
            slotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 60)
            },
            synchronization: .implicit,
            pacing: .none
        )
        firstBuffer.triggerRelease()

        try presenter.replaceAvailableBuffer(replacementBuffer, slotID: slotID)
        let replacementFrame = try await presenter.presentSlot(
            slotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 61)
            },
            synchronization: .implicit,
            pacing: .none
        )

        #expect(replacementFrame.slotID == slotID)
        #expect(firstBuffer.destroyCallCount == 1)
        #expect(replacementBuffer.destroyCallCount == 0)
        #expect(replacementBuffer.hasReleaseObserver)
        #expect(presenter.installedSlotIDs == [slotID])
        #expect(presenter.outstandingSubmittedSlotIDs == [slotID])
        #expect(
            await recorder.snapshot()
                == [firstBuffer.pointerValue, replacementBuffer.pointerValue]
        )
    }

    @Test
    func presenterRejectsReplacingSubmittedBuffer() async throws {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let submittedBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let replacementBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(submittedBuffer, slotID: slotID)
        _ = try await presenter.presentSlot(
            slotID,
            submit: { _, _, _ in
                try previewPresentationResult(generation: 70)
            },
            synchronization: .implicit,
            pacing: .none
        )

        do {
            try presenter.replaceAvailableBuffer(replacementBuffer, slotID: slotID)
            Issue.record("Expected submitted slot replacement to fail")
        } catch GPUWindowPresenterError.state(
            .pool(.slotNotAvailable(let failedSlotID, actual: .submitted(70)))
        ) {
            #expect(failedSlotID == slotID)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(submittedBuffer.destroyCallCount == 0)
        #expect(replacementBuffer.destroyCallCount == 0)
    }

    @Test
    func reconfigureRetiresAvailableBuffersThenLateReleaseAllowsNextSubmit()
        async throws
    {
        let presenter = GPUWindowPresenter()
        let recorder = SubmittedPointerRecorder()
        let oldSubmittedSlotID = try GBMBufferPoolSlotID(0)
        let oldAvailableSlotID = try GBMBufferPoolSlotID(1)
        let newSlotID = try GBMBufferPoolSlotID(2)
        let oldSubmittedBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let oldAvailableBuffer = try FakePresenterBuffer(pointer: 0x1002)
        let newBuffer = try FakePresenterBuffer(pointer: 0x1003)

        try presenter.installBuffer(oldSubmittedBuffer, slotID: oldSubmittedSlotID)
        try presenter.installBuffer(oldAvailableBuffer, slotID: oldAvailableSlotID)
        _ = try await presenter.presentSlot(
            oldSubmittedSlotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 80)
            },
            synchronization: .implicit,
            pacing: .none
        )

        #expect(
            try presenter.retireAvailableBuffers() == [oldAvailableSlotID]
        )
        #expect(oldSubmittedBuffer.destroyCallCount == 0)
        #expect(oldAvailableBuffer.destroyCallCount == 1)

        oldSubmittedBuffer.triggerRelease()
        try presenter.replaceAvailableBuffer(newBuffer, slotID: oldSubmittedSlotID)
        try presenter.installBuffer(try FakePresenterBuffer(pointer: 0x1004), slotID: newSlotID)

        let frame = try await presenter.presentSlot(
            oldSubmittedSlotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 81)
            },
            synchronization: .implicit,
            pacing: .none
        )

        #expect(frame.slotID == oldSubmittedSlotID)
        #expect(oldSubmittedBuffer.destroyCallCount == 1)
        #expect(newBuffer.destroyCallCount == 0)
        #expect(presenter.installedSlotIDs == [oldSubmittedSlotID, newSlotID])
        #expect(presenter.outstandingSubmittedSlotIDs == [oldSubmittedSlotID])
        #expect(
            await recorder.snapshot()
                == [oldSubmittedBuffer.pointerValue, newBuffer.pointerValue]
        )
    }

    @Test
    func releaseCallbackDuringInFlightPresentationKeepsPoolConsistent()
        async throws
    {
        let presenter = GPUWindowPresenter()
        let oldSubmittedSlotID = try GBMBufferPoolSlotID(0)
        let freshSlotID = try GBMBufferPoolSlotID(1)
        let oldSubmittedBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let freshBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(oldSubmittedBuffer, slotID: oldSubmittedSlotID)
        try presenter.installBuffer(freshBuffer, slotID: freshSlotID)
        _ = try await presenter.presentSlot(
            oldSubmittedSlotID,
            submit: { _, _, _ in
                try previewPresentationResult(generation: 90)
            },
            synchronization: .implicit,
            pacing: .none
        )

        let frame = try await presenter.presentSlot(
            freshSlotID,
            submit: { _, _, _ in
                oldSubmittedBuffer.triggerRelease()
                return try previewPresentationResult(generation: 91)
            },
            synchronization: .implicit,
            pacing: .none
        )

        #expect(frame.slotID == freshSlotID)
        #expect(presenter.availableSlotIDs == [oldSubmittedSlotID])
        #expect(presenter.outstandingSubmittedSlotIDs == [freshSlotID])
        #expect(presenter.releaseFailuresSnapshot.isEmpty)
    }

    @Test
    func explicitSubmissionIgnoresBufferReleaseUntilReleasePointSignal()
        async throws
    {
        let presenter = GPUWindowPresenter()
        let slotID = try GBMBufferPoolSlotID(0)
        let buffer = try FakePresenterBuffer(pointer: 0x1001)
        let releasePoint = syncPoint(timeline: 5, point: 8)

        try presenter.installBuffer(buffer, slotID: slotID)
        _ = try await presenter.presentSlot(
            slotID,
            submit: { _, _, _ in
                try previewPresentationResult(generation: 90)
            },
            synchronization: .explicit(
                GPUSubmittedBufferSyncState(
                    slotID: slotID,
                    acquirePoint: syncPoint(timeline: 5, point: 6),
                    releasePoint: releasePoint
                )
            ),
            pacing: .none
        )

        buffer.triggerRelease()

        #expect(presenter.availableSlotIDs.isEmpty)
        #expect(presenter.outstandingSubmittedSlotIDs == [slotID])
        #expect(presenter.releaseFailuresSnapshot.isEmpty)

        try presenter.recordExplicitReleaseSignal(slotID: slotID)

        #expect(presenter.availableSlotIDs == [slotID])
        #expect(presenter.outstandingSubmittedSlotIDs.isEmpty)
    }
}

@Suite
struct GPUWindowPresenterSlotSelectionTests {
    @Test
    func presenterSubmitsRequestedFreshSlotAfterLowerSlotRelease() async throws {
        let presenter = GPUWindowPresenter()
        let recorder = SubmittedPointerRecorder()
        let releasedSlotID = try GBMBufferPoolSlotID(0)
        let freshSlotID = try GBMBufferPoolSlotID(2)
        let releasedBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let freshBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(releasedBuffer, slotID: releasedSlotID)
        _ = try await presenter.presentSlot(
            releasedSlotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 40)
            },
            synchronization: .implicit,
            pacing: .none
        )
        releasedBuffer.triggerRelease()
        try presenter.installBuffer(freshBuffer, slotID: freshSlotID)

        let frame = try await presenter.presentSlot(
            freshSlotID,
            submit: { buffer, _, _ in
                await recorder.record(buffer)
                return try previewPresentationResult(generation: 41)
            },
            synchronization: .implicit,
            pacing: .none
        )

        #expect(frame.slotID == freshSlotID)
        #expect(
            await recorder.snapshot() == [releasedBuffer.pointerValue, freshBuffer.pointerValue])
        #expect(presenter.outstandingSubmittedSlotIDs == [freshSlotID])
    }
}

@Suite
struct ManagedGPUPreviewBackingConfigurationTests {
    @Test
    func renderTargetReuseRequiresMatchingSurfaceGeometry() throws {
        let geometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: .one
        )
        let resizedGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 5, height: 3),
            scale: .one
        )
        let scaledGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: SurfaceScale(integerScale: 2)
        )

        #expect(
            !ManagedGPUPreviewBacking.canReuseRenderTarget(
                configuredGeometry: nil,
                requestedGeometry: geometry
            )
        )
        #expect(
            ManagedGPUPreviewBacking.canReuseRenderTarget(
                configuredGeometry: geometry,
                requestedGeometry: geometry
            )
        )
        #expect(
            !ManagedGPUPreviewBacking.canReuseRenderTarget(
                configuredGeometry: geometry,
                requestedGeometry: resizedGeometry
            )
        )
        #expect(
            !ManagedGPUPreviewBacking.canReuseRenderTarget(
                configuredGeometry: geometry,
                requestedGeometry: scaledGeometry
            )
        )
    }
}

@Suite
struct ManagedGPUPreviewStoragePreparationTests {
    @Test
    func firstManagedGPUClearWaitsForInitialConfigureBeforeSubmit() async throws {
        let initialGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: .one
        )
        let configuredGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 8, height: 6),
            scale: .one
        )
        let window = FakeGraphicsPreviewWindow(
            initialGeometry: initialGeometry,
            configuredGeometry: configuredGeometry
        )
        let backing = FakeManagedGPUBacking()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuPreviewCapabilities()),
            configuration: .default,
            managedGPUBacking: backing
        )

        _ = try await storage.nextFrame()
        await window.clearEvents()
        let result = try await storage.submit(
            leaseID: 1,
            frame: .clearColor(.black)
        )

        #expect(await window.eventSnapshot() == [.preparePresentation, .geometry])
        #expect(backing.submittedGeometries == [configuredGeometry])
        #expect(result.size == configuredGeometry.bufferSize)
    }

    @Test
    func managedGPURedrawRefreshesGeometryBeforeLeaseAndSubmit() async throws {
        let initialGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: .one
        )
        let firstGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 8, height: 6),
            scale: .one
        )
        let leaseGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 10, height: 7),
            scale: .one
        )
        let submitGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 12, height: 9),
            scale: .one
        )
        let window = FakeGraphicsPreviewWindow(
            initialGeometry: initialGeometry,
            configuredGeometry: firstGeometry
        )
        let backing = FakeManagedGPUBacking()
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuPreviewCapabilities()),
            configuration: .default,
            managedGPUBacking: backing
        )

        _ = try await storage.nextFrame()
        _ = try await storage.submit(leaseID: 1, frame: .clearColor(.black))

        await window.setConfiguredGeometry(leaseGeometry)
        await window.clearEvents()
        let lease = try await storage.nextFrame()

        #expect(await window.eventSnapshot() == [.preparePresentation])
        #expect(lease.size == leaseGeometry.bufferSize)

        await window.setConfiguredGeometry(submitGeometry)
        await window.clearEvents()
        let result = try await lease.submit(.clearColor(.black))

        #expect(await window.eventSnapshot() == [.preparePresentation])
        #expect(backing.submittedGeometries == [firstGeometry, submitGeometry])
        #expect(result.size == submitGeometry.bufferSize)
    }

    @Test
    func committedGPUFailureDoesNotRetrySoftwareOrRollbackLease() async throws {
        let initialGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: .one
        )
        let configuredGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 8, height: 6),
            scale: .one
        )
        let failureSnapshot = GPURuntimePathSnapshot.afterPresentation(
            capabilities: capabilitySnapshot(),
            synchronization: .implicit,
            pacing: .none
        )
        .markingFailure(.gbmAllocationFailed)
        let window = FakeGraphicsPreviewWindow(
            initialGeometry: initialGeometry,
            configuredGeometry: configuredGeometry
        )
        let backing = FakeManagedGPUBacking(
            committedFrameFailures: [.gbmAllocationFailed],
            runtimePathSnapshot: failureSnapshot
        )
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: gpuPreviewCapabilities()),
            configuration: .default,
            managedGPUBacking: backing
        )

        let lease = try await storage.nextFrame()
        await window.clearEvents()
        do {
            _ = try await lease.submit(.clearColor(.black))
            Issue.record("expected committed GPU failure")
        } catch WaylandGraphicsError.unavailable(.gbmAllocationFailed) {
            #expect(
                await window.eventSnapshot() == [.preparePresentation, .geometry]
            )
            #expect(try await storage.runtimePath().backing == .failed(.gbmAllocationFailed))
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        let retryLease = try await storage.nextFrame()
        let retryResult = try await retryLease.submit(.clearColor(.black))

        #expect(retryResult.operation == .redraw)
        #expect(backing.submittedGeometries == [configuredGeometry, configuredGeometry])
    }

    @Test
    func requireExplicitGPUFailureDoesNotFallbackToSoftware() async throws {
        let initialGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 4, height: 3),
            scale: .one
        )
        let configuredGeometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 8, height: 6),
            scale: .one
        )
        let window = FakeGraphicsPreviewWindow(
            initialGeometry: initialGeometry,
            configuredGeometry: configuredGeometry
        )
        let backing = FakeManagedGPUBacking(
            setupFailures: [.explicitSyncSetupFailed]
        )
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .projected(capabilities: explicitSyncGPUPreviewCapabilities()),
            configuration: WaylandGraphicsConfiguration(
                synchronizationPolicy: .requireExplicit
            ),
            managedGPUBacking: backing
        )

        let lease = try await storage.nextFrame()
        await window.clearEvents()
        do {
            _ = try await lease.submit(.clearColor(.black))
            Issue.record("expected explicit sync setup failure")
        } catch WaylandGraphicsError.unavailable(.explicitSyncSetupFailed) {
            #expect(
                await window.eventSnapshot() == [.preparePresentation, .geometry]
            )
            #expect(backing.submittedGeometries == [configuredGeometry])
            #expect(
                try await storage.runtimePath().backing
                    == .failed(.explicitSyncSetupFailed)
            )
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

private func syncPoint(timeline: UInt64, point: UInt64) -> GPUSyncPoint {
    GPUSyncPoint(
        timeline: GPUSyncTimeline(timeline),
        point: RawSyncobjTimelinePoint(point)
    )
}

private func presentedFrame(
    slotID: GBMBufferPoolSlotID,
    generation: UInt64
) throws -> GPUWindowPresentedFrame {
    return GPUWindowPresentedFrame(
        slotID: slotID,
        generation: generation,
        commitPlan: try surfaceCommitPlan(),
        synchronization: .implicit,
        pacing: .none,
        metadata: .default
    )
}

private func gpuPreviewCapabilities() -> WaylandGraphicsSurfaceCapabilities {
    WaylandGraphicsSurfaceCapabilities(
        dmabuf: .available(version: 4),
        explicitSync: .unavailable,
        framePacing: .unavailable,
        colorMetadata: .unavailable,
        presentationFeedback: .unavailable
    )
}

private func explicitSyncGPUPreviewCapabilities() -> WaylandGraphicsSurfaceCapabilities {
    WaylandGraphicsSurfaceCapabilities(
        dmabuf: .available(version: 4),
        explicitSync: .available(version: 1),
        framePacing: .unavailable,
        colorMetadata: .unavailable,
        presentationFeedback: .unavailable
    )
}

private func previewPresentationResult(
    generation: UInt64 = 1,
    capabilities: SurfaceCapabilitySnapshot = capabilitySnapshot()
) throws -> PreviewBufferPresentationResult {
    try PreviewBufferPresentationResult(
        generation: generation,
        commitPlan: surfaceCommitPlan(),
        capabilities: capabilities
    )
}

private func surfaceCommitPlan() throws -> SurfaceCommitPlan {
    let geometry = try SurfaceGeometry(
        logicalSize: PositiveLogicalSize(width: 4, height: 3),
        scale: .one
    )

    return try SurfaceCommitPlan(
        geometry: geometry,
        bufferScale: 1,
        viewportMode: .omitDestination,
        damageMode: .buffer
    )
}

private func capabilitySnapshot(
    dmabuf: SurfaceDmabufCapability = .advertised(
        version: 1,
        canRequestSurfaceFeedback: .available
    ),
    synchronization: SurfaceSynchronizationCapability = .implicitOnly,
    pacing: SurfacePacingCapability = .unavailable,
    contentType: SurfaceCapabilityStatus = .unavailable,
    alphaModifier: SurfaceCapabilityStatus = .unavailable,
    tearingControl: SurfaceCapabilityStatus = .unavailable,
    colorRepresentation: SurfaceColorRepresentationCapability = .unavailable,
    color: SurfaceColorCapability = .unavailable
) -> SurfaceCapabilitySnapshot {
    SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .unavailable,
        dmabuf: dmabuf,
        synchronization: synchronization,
        pacing: pacing,
        contentType: contentType,
        alphaModifier: alphaModifier,
        tearingControl: tearingControl,
        colorRepresentation: colorRepresentation,
        color: color
    )
}

private func supportedColorRepresentationCapability()
    -> SurfaceColorRepresentationCapability
{
    .available(
        version: 1,
        support: SurfaceColorRepresentationSupport(
            alphaModes: [.straight],
            coefficientsAndRanges: []
        )
    )
}

private func invalidationReasons(
    oldMetadata: SurfaceCommitMetadata,
    newMetadata: SurfaceCommitMetadata,
    oldSnapshot: SurfaceCapabilitySnapshot = capabilitySnapshot(),
    newSnapshot: SurfaceCapabilitySnapshot = capabilitySnapshot()
) -> [GPUBackingInvalidationReason] {
    GPUBackingInvalidation.changes(
        oldSnapshot: oldSnapshot,
        newSnapshot: newSnapshot,
        oldMetadata: oldMetadata,
        newMetadata: newMetadata
    ).map(\.reason)
}

private enum FakeGraphicsPreviewWindowEvent: Equatable {
    case geometry
    case preparePresentation
    case show
    case redraw
}

private actor FakeGraphicsPreviewWindow: WaylandGraphicsManagedWindow {
    nonisolated let id = WindowID(rawValue: 710)
    private let initialGeometry: SurfaceGeometry
    private var configuredGeometry: SurfaceGeometry
    private var events: [FakeGraphicsPreviewWindowEvent] = []
    private var didPreparePresentation = false

    init(initialGeometry: SurfaceGeometry, configuredGeometry: SurfaceGeometry) {
        self.initialGeometry = initialGeometry
        self.configuredGeometry = configuredGeometry
    }

    var geometry: SurfaceGeometry {
        get async throws {
            events.append(.geometry)
            return didPreparePresentation ? configuredGeometry : initialGeometry
        }
    }

    var isClosed: Bool {
        get async throws { false }
    }

    func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceGeometry {
        events.append(.preparePresentation)
        didPreparePresentation = true
        return configuredGeometry
    }

    func show(
        timeoutMilliseconds _: Int32,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        damage _: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
        events.append(.show)
    }

    func redraw(
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        damage _: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
        events.append(.redraw)
    }

    func close() async {
        _ = ()
    }

    func clearEvents() {
        events.removeAll()
    }

    func setConfiguredGeometry(_ geometry: SurfaceGeometry) {
        configuredGeometry = geometry
    }

    func eventSnapshot() -> [FakeGraphicsPreviewWindowEvent] {
        events
    }
}

private final class FakeManagedGPUBacking: WaylandGraphicsManagedGPUBacking, Sendable {
    private let submittedGeometryState = Mutex<[SurfaceGeometry]>([])
    private let setupFailureState: Mutex<[GPUBackingFailure]>
    private let committedFrameFailureState: Mutex<[GPUBackingFailure]>
    private let runtimePathSnapshotValue: GPURuntimePathSnapshot

    init(
        setupFailures: [GPUBackingFailure] = [],
        committedFrameFailures: [GPUBackingFailure] = [],
        runtimePathSnapshot: GPURuntimePathSnapshot =
            .afterDmabufImportSetup(capabilities: capabilitySnapshot())
    ) {
        setupFailureState = Mutex(setupFailures)
        committedFrameFailureState = Mutex(committedFrameFailures)
        runtimePathSnapshotValue = runtimePathSnapshot
    }

    var runtimePathSnapshot: GPURuntimePathSnapshot {
        runtimePathSnapshotValue
    }

    var surfaceCapabilities: SurfaceCapabilitySnapshot? {
        capabilitySnapshot()
    }

    var submittedGeometries: [SurfaceGeometry] {
        submittedGeometryState.withLock { $0 }
    }

    func close() {
        _ = ()
    }

    func submitClearFrame(
        _ submission: WaylandGraphicsManagedGPUClearFrameSubmission
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        submittedGeometryState.withLock { $0.append(submission.geometry) }
        if let failure = setupFailureState.withLock({ failures in
            failures.isEmpty ? nil : failures.removeFirst()
        }) {
            throw .setup(failure)
        }
        if let failure = committedFrameFailureState.withLock({ failures in
            failures.isEmpty ? nil : failures.removeFirst()
        }) {
            throw .committedFrame(failure)
        }
        do {
            return try GPUWindowPresentedFrame(
                slotID: GBMBufferPoolSlotID(0),
                generation: 1,
                commitPlan: surfaceCommitPlan(),
                synchronization: .implicit,
                pacing: .none,
                metadata: submission.metadata
            )
        } catch {
            throw .setup(.gbmAllocationFailed)
        }
    }
}

private final class FakePresenterBuffer: GPUWindowPresenterBuffer {
    let pointerValue: UInt
    let surfaceBuffer: RawSurfaceBuffer
    private(set) var destroyCallCount = 0
    private var releaseObserver: (() -> Void)?

    init(pointer rawPointer: UInt) throws {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

        pointerValue = rawPointer
        surfaceBuffer = RawSurfaceBuffer(pointer: pointer)
    }

    var hasReleaseObserver: Bool {
        releaseObserver != nil
    }

    func setReleaseObserver(_ observer: @escaping () -> Void) {
        releaseObserver = observer
    }

    func destroy() {
        destroyCallCount += 1
        releaseObserver = nil
    }

    func triggerRelease() {
        releaseObserver?()
    }
}

private actor SubmittedPointerRecorder {
    private var values: [UInt] = []

    func record(_ buffer: RawSurfaceBuffer) {
        values.append(UInt(bitPattern: buffer.pointer))
    }

    func snapshot() -> [UInt] {
        values
    }
}
