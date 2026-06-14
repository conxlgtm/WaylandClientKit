import Glibc
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
    private static let releasePollTimeoutNanoseconds: Int64 = 0

    private var releaseTimelinesBySlot: [GBMBufferPoolSlotID: ManagedGPUExplicitReleaseTimeline] =
        [:]
    private let acquireTimeline: DRMSyncobjTimeline
    private let acquireIdentity: GPUSyncTimeline
    private var nextAcquirePoint: UInt64 = 1

    init(
        acquireTimeline syncAcquireTimeline: DRMSyncobjTimeline,
        identity timelineIdentity: GPUSyncTimeline
    ) {
        acquireTimeline = syncAcquireTimeline
        acquireIdentity = timelineIdentity
    }

    var placeholderSubmissionState: GPUSubmittedBufferSyncState {
        GPUSubmittedBufferSyncState(
            slotID: placeholderSlotID(),
            acquirePoint: GPUSyncPoint(
                timeline: acquireIdentity,
                point: RawSyncobjTimelinePoint(1)
            ),
            releasePoint: GPUSyncPoint(
                timeline: acquireIdentity,
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
        guard var releaseTimeline = releaseTimelinesBySlot[slotID] else {
            throw GBMAllocationError.syncobjCreationFailed(errno: EINVAL)
        }

        let acquirePoint = RawSyncobjTimelinePoint(nextAcquirePoint)
        let releasePoint = RawSyncobjTimelinePoint(releaseTimeline.nextPoint)
        nextAcquirePoint += 1
        releaseTimeline.nextPoint += 1
        releaseTimelinesBySlot[slotID] = releaseTimeline

        try acquireTimeline.signal(acquirePoint)

        return GPUSubmittedBufferSyncState(
            slotID: slotID,
            acquirePoint: GPUSyncPoint(
                timeline: acquireIdentity,
                point: acquirePoint
            ),
            releasePoint: GPUSyncPoint(
                timeline: releaseTimeline.identity,
                point: releasePoint
            )
        )
    }

    func hasReleaseTimeline(for slotID: GBMBufferPoolSlotID) -> Bool {
        releaseTimelinesBySlot[slotID] != nil
    }

    func installReleaseTimeline(
        _ timeline: DRMSyncobjTimeline,
        identity timelineIdentity: GPUSyncTimeline,
        for slotID: GBMBufferPoolSlotID
    ) {
        releaseTimelinesBySlot[slotID] = ManagedGPUExplicitReleaseTimeline(
            timeline: timeline,
            identity: timelineIdentity
        )
    }

    func ownsReleaseTimeline(_ timeline: GPUSyncTimeline) -> Bool {
        releaseTimelinesBySlot.values.contains { releaseTimeline in
            releaseTimeline.identity == timeline
        }
    }

    func hasOutstandingReleaseTimeline(
        in states: [GPUSubmittedBufferSyncState]
    ) -> Bool {
        states.contains { state in
            ownsReleaseTimeline(state.releasePoint.timeline)
        }
    }

    func waitForRelease(
        _ state: GPUSubmittedBufferSyncState
    ) throws(GBMAllocationError) {
        guard let releaseTimeline = releaseTimeline(for: state.releasePoint.timeline) else {
            throw GBMAllocationError.syncobjTimelineWaitFailed(
                point: state.releasePoint.point.rawValue,
                errno: EINVAL
            )
        }

        try releaseTimeline.timeline.wait(
            state.releasePoint.point,
            timeoutNanoseconds: Self.releaseWaitTimeoutNanoseconds,
            waitForSubmit: true
        )
    }

    func releasePointIsSignaled(
        _ state: GPUSubmittedBufferSyncState
    ) throws(GBMAllocationError) -> Bool {
        guard let releaseTimeline = releaseTimeline(for: state.releasePoint.timeline) else {
            throw GBMAllocationError.syncobjTimelineWaitFailed(
                point: state.releasePoint.point.rawValue,
                errno: EINVAL
            )
        }

        do {
            try releaseTimeline.timeline.wait(
                state.releasePoint.point,
                timeoutNanoseconds: Self.releasePollTimeoutNanoseconds,
                waitForSubmit: true
            )
            return true
        } catch {
            if error.isSyncobjTimelineWaitTimeout {
                return false
            }
            throw error
        }
    }

    private func releaseTimeline(
        for timeline: GPUSyncTimeline
    ) -> ManagedGPUExplicitReleaseTimeline? {
        releaseTimelinesBySlot.values.first { releaseTimeline in
            releaseTimeline.identity == timeline
        }
    }

    func destroy() {
        acquireTimeline.destroy()
        for releaseTimeline in releaseTimelinesBySlot.values {
            releaseTimeline.timeline.destroy()
        }
        releaseTimelinesBySlot.removeAll()
    }
}

private struct ManagedGPUExplicitReleaseTimeline {
    let timeline: DRMSyncobjTimeline
    let identity: GPUSyncTimeline
    var nextPoint: UInt64 = 1
}
