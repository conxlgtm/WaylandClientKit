import WaylandClient
import WaylandGraphicsCore
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
    case committedUntracked
    case retired
}

package enum RuntimePathStatus: Equatable, Sendable {
    case unavailable
    case advertised
    case configured
    case active
    case failed(GPURuntimePathReason)
    case fallback(GPURuntimePathReason)
}

package enum GPURuntimePathReason: Equatable, Sendable {
    case policyForcedSHM
    case dmabufUnavailable
    case surfaceFeedbackUnavailable
    case noCompatibleFormat
    case noRenderNode
    case gbmUnavailable
    case gbmAllocationFailed
    case eglUnavailable
    case explicitSynchronizationUnavailable
    case explicitSynchronizationNotConfigured
    case fifoUnavailable
    case commitTimingUnavailable
    case commitTimingRejected
    case contentTypeUnavailable
    case alphaModifierUnavailable
    case colorRepresentationUnavailable
    case colorRepresentationSupportPending
    case colorManagementUnavailable
    case presentationHintUnavailable
    case compositorRejectedBuffer
    case commitFailed
    case presentationTrackingFailed
}

package enum GPUSynchronizationRuntimeStatus: Equatable, Sendable {
    case implicit
    case explicitAdvertised
    case explicitConfigured
    case explicitActive
    case explicitFallback(GPURuntimePathReason)
    case explicitFailed(GPURuntimePathReason)
}

package enum GPUFramePacingRuntimeStatus: Equatable, Sendable {
    case none
    case fifoAdvertised
    case commitTimingAdvertised
    case fifoAndCommitTimingAdvertised
    case fifoActive
    case commitTimingActive
    case fifoAndCommitTimingActive
    case failed(GPURuntimePathReason)
    case fallback(GPURuntimePathReason)
}

package struct GPURuntimePathSnapshot: Equatable, Sendable {
    package var dmabuf: RuntimePathStatus
    package var surfaceFeedback: RuntimePathStatus
    package var renderNode: RuntimePathStatus
    package var gbm: RuntimePathStatus
    package var egl: RuntimePathStatus
    package var dmabufImport: RuntimePathStatus
    package var bufferLifecycle: RuntimePathStatus
    package var synchronization: GPUSynchronizationRuntimeStatus
    package var pacing: GPUFramePacingRuntimeStatus
    package var presentationFeedback: SurfaceCapabilityStatus
    package var contentType: RuntimePathStatus
    package var alpha: RuntimePathStatus
    package var tearingControl: RuntimePathStatus
    package var colorRepresentation: RuntimePathStatus
    package var colorManagement: RuntimePathStatus
    package var presentationHint: SurfacePresentationHint?

    package static let empty = Self(
        dmabuf: .unavailable,
        surfaceFeedback: .unavailable,
        renderNode: .unavailable,
        gbm: .unavailable,
        egl: .unavailable,
        dmabufImport: .unavailable,
        bufferLifecycle: .unavailable,
        synchronization: .implicit,
        pacing: .none,
        presentationFeedback: .unavailable,
        contentType: .unavailable,
        alpha: .unavailable,
        tearingControl: .unavailable,
        colorRepresentation: .unavailable,
        colorManagement: .unavailable,
        presentationHint: nil
    )

    package static func afterPresentation(
        capabilities: SurfaceCapabilitySnapshot,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata = .default
    ) -> Self {
        Self(
            dmabuf: dmabufStatus(capabilities.dmabuf),
            surfaceFeedback: surfaceFeedbackStatus(capabilities.dmabuf),
            renderNode: .active,
            gbm: .active,
            egl: .configured,
            dmabufImport: .active,
            bufferLifecycle: .active,
            synchronization: synchronizationStatus(
                synchronization,
                capability: capabilities.synchronization
            ),
            pacing: pacingStatus(pacing, capability: capabilities.pacing),
            presentationFeedback: capabilities.presentationFeedback,
            contentType: capabilityStatus(
                capabilities.contentType,
                requested: metadata.contentType != nil,
                missingReason: .contentTypeUnavailable
            ),
            alpha: capabilityStatus(
                capabilities.alphaModifier,
                requested: metadata.alpha != nil,
                missingReason: .alphaModifierUnavailable
            ),
            tearingControl: capabilityStatus(
                capabilities.tearingControl,
                requested: metadata.presentationHint != nil,
                missingReason: .presentationHintUnavailable
            ),
            colorRepresentation: colorRepresentationStatus(
                capabilities.colorRepresentation,
                requested: metadata.colorRepresentation != nil
            ),
            colorManagement: colorStatus(
                capabilities.color,
                requested: metadata.colorDescription != nil
            ),
            presentationHint: metadata.presentationHint
        )
    }

    package static func dmabufStatus(
        _ capability: SurfaceDmabufCapability
    ) -> RuntimePathStatus {
        switch capability {
        case .unavailable:
            .unavailable
        case .advertised:
            .advertised
        case .surfaceFeedback:
            .active
        }
    }

    package static func surfaceFeedbackStatus(
        _ capability: SurfaceDmabufCapability
    ) -> RuntimePathStatus {
        switch capability {
        case .unavailable:
            .unavailable
        case .advertised(_, let canRequestSurfaceFeedback):
            capabilityStatus(
                canRequestSurfaceFeedback,
                requested: false,
                missingReason: .surfaceFeedbackUnavailable
            )
        case .surfaceFeedback:
            .active
        }
    }

    package static func synchronizationStatus(
        _ synchronization: GPUBufferSubmissionSynchronization,
        capability: SurfaceSynchronizationCapability
    ) -> GPUSynchronizationRuntimeStatus {
        switch synchronization {
        case .explicit:
            return .explicitActive
        case .implicit:
            switch capability {
            case .implicitOnly:
                return .implicit
            case .explicitAvailable:
                return .explicitAdvertised
            case .explicitActive:
                return .explicitConfigured
            }
        }
    }

    package static func pacingStatus(
        _ pacing: SurfacePacingConstraint,
        capability: SurfacePacingCapability
    ) -> GPUFramePacingRuntimeStatus {
        switch pacing {
        case .fifo:
            return .fifoActive
        case .targetTime:
            return .commitTimingActive
        case .fifoAndTargetTime:
            return .fifoAndCommitTimingActive
        case .none:
            switch capability {
            case .unavailable:
                return .none
            case .fifo:
                return .fifoAdvertised
            case .commitTiming:
                return .commitTimingAdvertised
            case .fifoAndCommitTiming:
                return .fifoAndCommitTimingAdvertised
            }
        }
    }

    package static func capabilityStatus(
        _ capability: SurfaceCapabilityStatus,
        requested: Bool,
        missingReason: GPURuntimePathReason
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true):
            .configured
        case (.available, false):
            .advertised
        case (.unavailable, true):
            .failed(missingReason)
        case (.unavailable, false):
            .unavailable
        }
    }

    package static func colorRepresentationStatus(
        _ capability: SurfaceColorRepresentationCapability,
        requested: Bool
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true):
            .configured
        case (.available, false):
            .advertised
        case (.pending, true):
            .failed(.colorRepresentationSupportPending)
        case (.pending, false):
            .advertised
        case (.unavailable, true):
            .failed(.colorRepresentationUnavailable)
        case (.unavailable, false):
            .unavailable
        }
    }

    package static func colorStatus(
        _ capability: SurfaceColorCapability,
        requested: Bool
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true),
            (.preferredDescription, true):
            .configured
        case (.available, false),
            (.preferredDescription, false):
            .advertised
        case (.unavailable, true):
            .failed(.colorManagementUnavailable)
        case (.unavailable, false):
            .unavailable
        }
    }
}

package struct GPUWindowPresentationCorrelation: Equatable, Sendable {
    private var slotsByGeneration: [UInt64: GBMBufferPoolSlotID] = [:]

    package init() {
        // Frames are recorded after successful surface commits.
    }

    package var count: Int {
        slotsByGeneration.count
    }

    package var isEmpty: Bool {
        slotsByGeneration.isEmpty
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
