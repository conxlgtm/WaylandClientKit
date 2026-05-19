import WaylandClient

extension GPURuntimePathSnapshot {
    package static func afterCapabilityDiscovery(
        capabilities: SurfaceCapabilitySnapshot
    ) -> Self {
        Self(
            dmabuf: dmabufStatus(capabilities.dmabuf),
            gbm: .unavailable,
            egl: .unavailable,
            synchronization: synchronizationStatus(
                .implicit,
                capability: capabilities.synchronization
            ),
            pacing: pacingStatus(.none, capability: capabilities.pacing),
            presentationFeedback: capabilities.presentationFeedback,
            contentType: capabilityStatus(
                capabilities.contentType,
                requested: false,
                missingReason: .contentTypeUnavailable
            ),
            alpha: capabilityStatus(
                capabilities.alphaModifier,
                requested: false,
                missingReason: .alphaModifierUnavailable
            ),
            colorRepresentation: colorRepresentationStatus(
                capabilities.colorRepresentation,
                requested: false
            ),
            colorManagement: colorStatus(capabilities.color, requested: false),
            presentationHint: nil
        )
    }

    package static func afterGBMDeviceSelection(
        capabilities: SurfaceCapabilitySnapshot
    ) -> Self {
        var snapshot = afterCapabilityDiscovery(capabilities: capabilities)
        snapshot.gbm = .configured
        return snapshot
    }

    package static func afterEGLTargetSetup(
        capabilities: SurfaceCapabilitySnapshot
    ) -> Self {
        var snapshot = afterGBMDeviceSelection(capabilities: capabilities)
        snapshot.egl = .configured
        return snapshot
    }

    package static func afterDmabufImportSetup(
        capabilities: SurfaceCapabilitySnapshot
    ) -> Self {
        var snapshot = afterEGLTargetSetup(capabilities: capabilities)
        snapshot.dmabuf = dmabufStatus(capabilities.dmabuf).activated
        return snapshot
    }

    package static func afterSubmitObjectInstallation(
        capabilities: SurfaceCapabilitySnapshot,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint
    ) -> Self {
        var snapshot = afterDmabufImportSetup(capabilities: capabilities)
        snapshot.synchronization = synchronizationStatus(
            synchronization,
            capability: capabilities.synchronization
        )
        snapshot.pacing = pacingStatus(pacing, capability: capabilities.pacing)
        return snapshot
    }

    package static func afterMetadataObjectInstallation(
        capabilities: SurfaceCapabilitySnapshot,
        metadata: SurfaceCommitMetadata
    ) -> Self {
        var snapshot = afterDmabufImportSetup(capabilities: capabilities)
        snapshot.contentType = capabilityStatus(
            capabilities.contentType,
            requested: metadata.contentType != nil,
            missingReason: .contentTypeUnavailable
        )
        snapshot.alpha = capabilityStatus(
            capabilities.alphaModifier,
            requested: metadata.alpha != nil,
            missingReason: .alphaModifierUnavailable
        )
        snapshot.colorRepresentation = colorRepresentationStatus(
            capabilities.colorRepresentation,
            requested: metadata.colorRepresentation != nil
        )
        snapshot.colorManagement = colorStatus(
            capabilities.color,
            requested: metadata.colorDescription != nil
        )
        snapshot.presentationHint = metadata.presentationHint
        return snapshot
    }

    package static func afterFallback(
        capabilities: SurfaceCapabilitySnapshot,
        reason: GPUFallbackReason
    ) -> Self {
        var snapshot = afterCapabilityDiscovery(capabilities: capabilities)
        let runtimeReason = GPURuntimePathReason(reason)
        snapshot.dmabuf = snapshot.dmabuf.fallback(runtimeReason)
        snapshot.gbm = .fallback(runtimeReason)
        snapshot.egl = .fallback(runtimeReason)
        if reason == .explicitSyncRequiredButUnavailable {
            snapshot.synchronization = .explicitFallback(runtimeReason)
        }
        if reason == .metadataRequiredButUnavailable {
            snapshot.contentType = snapshot.contentType.fallback(runtimeReason)
            snapshot.alpha = snapshot.alpha.fallback(runtimeReason)
            snapshot.colorRepresentation = snapshot.colorRepresentation.fallback(
                runtimeReason
            )
            snapshot.colorManagement = snapshot.colorManagement.fallback(runtimeReason)
        }
        return snapshot
    }

    package static func afterFailure(
        capabilities: SurfaceCapabilitySnapshot,
        failure: GPUBackingFailure
    ) -> Self {
        var snapshot = afterCapabilityDiscovery(capabilities: capabilities)
        let runtimeReason = GPURuntimePathReason(failure)
        switch failure {
        case .dmabufUnavailable, .compositorRejectedBuffer:
            snapshot.dmabuf = .failed(runtimeReason)
        case .noCompatibleFormat, .noRenderNode, .gbmUnavailable,
            .gbmAllocationFailed:
            snapshot.gbm = .failed(runtimeReason)
        case .eglUnavailable:
            snapshot.egl = .failed(runtimeReason)
        case .explicitSyncRequiredButUnavailable, .submitConstraintRejected:
            snapshot.synchronization = .explicitFailed(runtimeReason)
        case .metadataRequiredButUnavailable:
            snapshot.contentType = .failed(runtimeReason)
            snapshot.alpha = .failed(runtimeReason)
            snapshot.colorRepresentation = .failed(runtimeReason)
            snapshot.colorManagement = .failed(runtimeReason)
        case .commitFailed:
            snapshot.dmabuf = snapshot.dmabuf.failed(runtimeReason)
        }
        return snapshot
    }
}

extension RuntimePathStatus {
    package var activated: RuntimePathStatus {
        switch self {
        case .unavailable:
            .failed(.dmabufUnavailable)
        case .advertised, .configured, .active:
            .active
        case .failed, .fallback:
            self
        }
    }

    package func fallback(_ reason: GPURuntimePathReason) -> RuntimePathStatus {
        switch self {
        case .unavailable:
            .unavailable
        case .advertised, .configured, .active:
            .fallback(reason)
        case .failed, .fallback:
            self
        }
    }

    package func failed(_ reason: GPURuntimePathReason) -> RuntimePathStatus {
        switch self {
        case .unavailable:
            .failed(reason)
        case .advertised, .configured, .active:
            .failed(reason)
        case .failed, .fallback:
            self
        }
    }
}

extension GPURuntimePathReason {
    package init(_ fallbackReason: GPUFallbackReason) {
        switch fallbackReason {
        case .explicitSyncRequiredButUnavailable:
            self = .explicitSynchronizationUnavailable
        case .metadataRequiredButUnavailable:
            self = .colorManagementUnavailable
        case .gbmUnavailable, .noCompatibleFormat, .noRenderNode:
            self = .gbmUnavailable
        case .eglUnavailable:
            self = .eglUnavailable
        default:
            self = .dmabufUnavailable
        }
    }

    package init(_ failure: GPUBackingFailure) {
        switch failure {
        case .explicitSyncRequiredButUnavailable, .submitConstraintRejected:
            self = .explicitSynchronizationUnavailable
        case .metadataRequiredButUnavailable:
            self = .colorManagementUnavailable
        case .gbmUnavailable, .gbmAllocationFailed, .noCompatibleFormat,
            .noRenderNode:
            self = .gbmUnavailable
        case .eglUnavailable:
            self = .eglUnavailable
        default:
            self = .dmabufUnavailable
        }
    }
}
