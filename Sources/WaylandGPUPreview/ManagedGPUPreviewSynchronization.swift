import WaylandClient
import WaylandGraphicsCore
import WaylandRaw

struct ManagedGPUPreviewSubmissionContext {
    let capabilities: SurfaceCapabilitySnapshot
    let renderTarget: EGLGBMRenderTarget
    let options: ManagedGPUPreviewPresentationOptions
}

struct ManagedGPUPreviewPresentationOptions {
    let metadata: SurfaceCommitMetadata
    let synchronization: ManagedGPUPreviewSynchronizationSelection
    let pacing: SurfacePacingConstraint
    let pacingFallbackReason: GPURuntimePathReason?
    let requestPresentationFeedback: Bool
}

enum ManagedGPUPreviewSynchronizationSelection {
    case implicit(fallbackReason: GPURuntimePathReason? = nil)
    case explicit(ManagedGPUExplicitSynchronization)

    var fallbackReason: GPURuntimePathReason? {
        switch self {
        case .implicit(let fallbackReason):
            fallbackReason
        case .explicit:
            nil
        }
    }

    var requirementSynchronization: GPUBufferSubmissionSynchronization {
        switch self {
        case .implicit:
            .implicit
        case .explicit(let explicitSynchronization):
            .explicit(explicitSynchronization.placeholderSubmissionState)
        }
    }

    func submissionSynchronization(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMAllocationError) -> GPUBufferSubmissionSynchronization {
        switch self {
        case .implicit:
            .implicit
        case .explicit(let explicitSynchronization):
            try .explicit(explicitSynchronization.submissionState(for: slotID))
        }
    }

    func waitForExplicitRelease(
        _ synchronization: GPUBufferSubmissionSynchronization
    ) throws(GBMAllocationError) {
        guard
            case .explicit(let explicitSynchronization) = self,
            case .explicit(let submittedState) = synchronization
        else {
            return
        }

        try explicitSynchronization.waitForRelease(submittedState)
    }
}

final class ManagedGPUExplicitSynchronization {
    private static let releaseWaitTimeoutNanoseconds: Int64 = 1_000_000_000

    private let timeline: DRMSyncobjTimeline
    private let identity: GPUSyncTimeline
    private var nextPoint: UInt64 = 1

    init(
        timeline syncTimeline: DRMSyncobjTimeline,
        identity timelineIdentity: GPUSyncTimeline
    ) {
        timeline = syncTimeline
        identity = timelineIdentity
    }

    var explicitSynchronization: GPUExplicitSynchronization {
        GPUExplicitSynchronization(acquireTimeline: identity, releaseTimeline: identity)
    }

    var placeholderSubmissionState: GPUSubmittedBufferSyncState {
        GPUSubmittedBufferSyncState(
            slotID: placeholderSlotID(),
            acquirePoint: GPUSyncPoint(
                timeline: identity,
                point: RawSyncobjTimelinePoint(1)
            ),
            releasePoint: GPUSyncPoint(
                timeline: identity,
                point: RawSyncobjTimelinePoint(2)
            )
        )
    }

    private func placeholderSlotID() -> GBMBufferPoolSlotID {
        do {
            return try GBMBufferPoolSlotID(0)
        } catch {
            preconditionFailure("Zero is always a valid GPU buffer slot ID")
        }
    }

    func submissionState(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMAllocationError) -> GPUSubmittedBufferSyncState {
        let acquirePoint = RawSyncobjTimelinePoint(nextPoint)
        let releasePoint = RawSyncobjTimelinePoint(nextPoint + 1)
        nextPoint += 2

        try timeline.signal(acquirePoint)

        return GPUSubmittedBufferSyncState(
            slotID: slotID,
            acquirePoint: GPUSyncPoint(
                timeline: identity,
                point: acquirePoint
            ),
            releasePoint: GPUSyncPoint(
                timeline: identity,
                point: releasePoint
            )
        )
    }

    func waitForRelease(
        _ state: GPUSubmittedBufferSyncState
    ) throws(GBMAllocationError) {
        try timeline.wait(
            state.releasePoint.point,
            timeoutNanoseconds: Self.releaseWaitTimeoutNanoseconds
        )
    }

    func destroy() {
        timeline.destroy()
    }
}
