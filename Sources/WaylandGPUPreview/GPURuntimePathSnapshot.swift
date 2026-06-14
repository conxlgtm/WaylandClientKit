import WaylandClient

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
    case explicitSynchronizationSetupFailed
    case explicitSynchronizationSubmissionFailed
    case explicitSynchronizationReleaseFailed
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
            contentType: activeCapabilityStatus(
                capabilities.contentType,
                requested: metadata.contentType != nil,
                missingReason: .contentTypeUnavailable
            ),
            alpha: activeCapabilityStatus(
                capabilities.alphaModifier,
                requested: metadata.alpha != nil,
                missingReason: .alphaModifierUnavailable
            ),
            tearingControl: activeCapabilityStatus(
                capabilities.tearingControl,
                requested: metadata.presentationHint != nil,
                missingReason: .presentationHintUnavailable
            ),
            colorRepresentation: activeColorRepresentationStatus(
                capabilities.colorRepresentation,
                requested: metadata.colorRepresentation != nil
            ),
            colorManagement: activeColorStatus(
                capabilities.color,
                requested: metadata.colorDescription != nil
            ),
            presentationHint: metadata.presentationHint
        )
    }
}

extension GPURuntimePathSnapshot {
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
            return advertisedPacingStatus(capability)
        }
    }

    package static func advertisedPacingStatus(
        _ capability: SurfacePacingCapability
    ) -> GPUFramePacingRuntimeStatus {
        switch capability {
        case .unavailable:
            .none
        case .fifo:
            .fifoAdvertised
        case .commitTiming:
            .commitTimingAdvertised
        case .fifoAndCommitTiming:
            .fifoAndCommitTimingAdvertised
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

    package static func activeCapabilityStatus(
        _ capability: SurfaceCapabilityStatus,
        requested: Bool,
        missingReason: GPURuntimePathReason
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true):
            .active
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

    package static func activeColorRepresentationStatus(
        _ capability: SurfaceColorRepresentationCapability,
        requested: Bool
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true):
            .active
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

    package static func activeColorStatus(
        _ capability: SurfaceColorCapability,
        requested: Bool
    ) -> RuntimePathStatus {
        switch (capability, requested) {
        case (.available, true),
            (.preferredDescription, true):
            .active
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
