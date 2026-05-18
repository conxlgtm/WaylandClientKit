import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

package struct GPUSyncTimeline: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(_ value: UInt64) {
        rawValue = value
    }
}

package struct GPUSyncPoint: Equatable, Sendable {
    package let timeline: GPUSyncTimeline
    package let point: RawSyncobjTimelinePoint

    package init(timeline syncTimeline: GPUSyncTimeline, point syncPoint: RawSyncobjTimelinePoint) {
        timeline = syncTimeline
        point = syncPoint
    }

    package var surfaceSyncPoint: SurfaceSyncPoint {
        SurfaceSyncPoint(
            timeline: SurfaceSyncTimelineIdentity(timeline.rawValue),
            point: point
        )
    }
}

package struct GPUExplicitSynchronization: Equatable, Sendable {
    package let acquireTimeline: GPUSyncTimeline?
    package let releaseTimeline: GPUSyncTimeline

    package init(
        acquireTimeline syncAcquireTimeline: GPUSyncTimeline?,
        releaseTimeline syncReleaseTimeline: GPUSyncTimeline
    ) {
        acquireTimeline = syncAcquireTimeline
        releaseTimeline = syncReleaseTimeline
    }
}

package enum GPUSynchronizationMode: Equatable, Sendable {
    case implicit
    case explicit(GPUExplicitSynchronization)
}

package enum GPUSynchronizationPolicy: Equatable, Sendable {
    case preferExplicitFallbackToImplicit
    case requireExplicit
    case implicitOnly

    package func selectMode(
        capability: SurfaceSynchronizationCapability,
        explicitSynchronization: GPUExplicitSynchronization?
    ) throws(GPUSynchronizationPolicyError) -> GPUSynchronizationMode {
        switch self {
        case .implicitOnly:
            return .implicit
        case .preferExplicitFallbackToImplicit:
            guard
                supportsExplicitSynchronization(capability),
                let explicitSynchronization
            else {
                return .implicit
            }

            return .explicit(explicitSynchronization)
        case .requireExplicit:
            guard supportsExplicitSynchronization(capability) else {
                throw .explicitSynchronizationUnavailable
            }
            guard let explicitSynchronization else {
                throw .explicitSynchronizationNotConfigured
            }

            return .explicit(explicitSynchronization)
        }
    }
}

private func supportsExplicitSynchronization(
    _ capability: SurfaceSynchronizationCapability
) -> Bool {
    switch capability {
    case .implicitOnly:
        false
    case .explicitAvailable, .explicitActive:
        true
    }
}

package enum GPUSynchronizationPolicyError: Error, Equatable, Sendable {
    case explicitSynchronizationUnavailable
    case explicitSynchronizationNotConfigured
}

package enum GPUFramePacingMode: Equatable, Sendable {
    case none
    case fifo(FifoMode)
}

package enum GPUCommitTimingMode: Equatable, Sendable {
    case none
    case target(SurfaceCommitTargetTime)
}

package enum GPUBufferSubmissionSynchronization: Equatable, Sendable {
    case implicit
    case explicit(GPUSubmittedBufferSyncState)

    package var submitConstraint: SurfaceSynchronizationConstraint {
        switch self {
        case .implicit:
            .implicit
        case .explicit(let state):
            .explicit(
                acquire: state.acquirePoint?.surfaceSyncPoint,
                release: state.releasePoint.surfaceSyncPoint
            )
        }
    }
}

package struct GPUSubmittedBufferSyncState: Equatable, Sendable {
    package let slotID: GBMBufferPoolSlotID
    package let acquirePoint: GPUSyncPoint?
    package let releasePoint: GPUSyncPoint

    package init(
        slotID submittedSlotID: GBMBufferPoolSlotID,
        acquirePoint submittedAcquirePoint: GPUSyncPoint?,
        releasePoint submittedReleasePoint: GPUSyncPoint
    ) {
        slotID = submittedSlotID
        acquirePoint = submittedAcquirePoint
        releasePoint = submittedReleasePoint
    }
}

package enum GPUBufferSubmissionState: Equatable, Sendable {
    case available
    case leased
    case submittedImplicit(commitGeneration: UInt64)
    case submittedExplicit(commitGeneration: UInt64, releasePoint: GPUSyncPoint)
    case retired
}

package enum RuntimePathStatus: Equatable, Sendable {
    case unavailable
    case available
    case active
}

package enum GPUSynchronizationRuntimeStatus: Equatable, Sendable {
    case implicit
    case explicitActive
    case explicitUnavailableFallback
    case explicitRequiredUnavailable
}

package enum GPUFramePacingRuntimeStatus: Equatable, Sendable {
    case none
    case fifoActive
    case commitTimingActive
    case fifoAndCommitTimingActive
    case unavailable
}

package struct GPURuntimePathSnapshot: Equatable, Sendable {
    package let dmabuf: RuntimePathStatus
    package let gbm: RuntimePathStatus
    package let egl: RuntimePathStatus
    package let synchronization: GPUSynchronizationRuntimeStatus
    package let pacing: GPUFramePacingRuntimeStatus
    package let presentationFeedback: SurfaceCapabilityStatus

    package static let empty = Self(
        dmabuf: .unavailable,
        gbm: .unavailable,
        egl: .unavailable,
        synchronization: .implicit,
        pacing: .none,
        presentationFeedback: .unavailable
    )
}

package struct GPUWindowPresentationCorrelation: Equatable, Sendable {
    private var slotsByGeneration: [UInt64: GBMBufferPoolSlotID] = [:]

    package init() {
        // Frames are recorded after successful surface commits.
    }

    package mutating func record(_ frame: GPUWindowPresentedFrame) {
        slotsByGeneration[frame.generation] = frame.slotID
    }

    package func slotID(for generation: UInt64) -> GBMBufferPoolSlotID? {
        slotsByGeneration[generation]
    }

    package mutating func takeSlotID(for generation: UInt64) -> GBMBufferPoolSlotID? {
        slotsByGeneration.removeValue(forKey: generation)
    }

    package mutating func remove(generation: UInt64) {
        slotsByGeneration.removeValue(forKey: generation)
    }

    package mutating func remove(slotID: GBMBufferPoolSlotID) {
        slotsByGeneration = slotsByGeneration.filter { _, correlatedSlotID in
            correlatedSlotID != slotID
        }
    }

    package mutating func removeAll() {
        slotsByGeneration.removeAll()
    }
}
