// swiftlint:disable file_length
import Testing

@testable import WaylandClient
@testable import WaylandGPUPreview
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
    func explicitSubmissionIgnoresBufferReleaseUntilReleasePointSignals() throws {
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

        #expect(try state.markExplicitReleaseSignaled(slotID))

        #expect(try state.submissionState(for: slotID) == .available)

        #expect(try state.markReleased(slotID) == false)
        #expect(try state.markExplicitReleaseSignaled(slotID) == false)

        #expect(try state.submissionState(for: slotID) == .available)

        _ = try state.leaseNext()

        #expect(try state.markReleased(slotID) == false)
        #expect(try state.markExplicitReleaseSignaled(slotID) == false)
        #expect(try state.submissionState(for: slotID) == .leased)
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

        #expect(snapshot.contentType == .configured)
        #expect(snapshot.alpha == .configured)
        #expect(snapshot.colorRepresentation == .configured)
        #expect(snapshot.colorManagement == .configured)
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
    func presenterRetireAllDestroysInstalledBuffersOnce() throws {
        let presenter = GPUWindowPresenter()
        let firstSlotID = try GBMBufferPoolSlotID(0)
        let secondSlotID = try GBMBufferPoolSlotID(1)
        let firstBuffer = try FakePresenterBuffer(pointer: 0x1001)
        let secondBuffer = try FakePresenterBuffer(pointer: 0x1002)

        try presenter.installBuffer(firstBuffer, slotID: firstSlotID)
        try presenter.installBuffer(secondBuffer, slotID: secondSlotID)
        presenter.retireAll(reason: .windowClosed)

        #expect(firstBuffer.destroyCallCount == 1)
        #expect(secondBuffer.destroyCallCount == 1)
        #expect(presenter.installedSlotIDs.isEmpty)
        #expect(presenter.outstandingSubmittedSlotIDs.isEmpty)

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
    let geometry = try SurfaceGeometry(
        logicalSize: PositiveLogicalSize(width: 4, height: 3),
        scale: .one
    )

    return GPUWindowPresentedFrame(
        slotID: slotID,
        generation: generation,
        commitPlan: SurfaceCommitPlan(
            geometry: geometry,
            bufferScale: 1,
            viewportMode: .omitDestination,
            damageMode: .buffer
        ),
        synchronization: .implicit,
        pacing: .none,
        metadata: .default
    )
}

private func capabilitySnapshot(
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
        dmabuf: .advertised(version: 1, canRequestSurfaceFeedback: .available),
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

private final class FakePresenterBuffer: GPUWindowPresenterBuffer {
    let surfaceBuffer: RawSurfaceBuffer
    private(set) var destroyCallCount = 0
    private var releaseObserver: (() -> Void)?

    init(pointer rawPointer: UInt) throws {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

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
