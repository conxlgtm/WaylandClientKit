import WaylandClient

extension GPURuntimePathSnapshot {
    package static func afterCapabilityDiscovery(
        capabilities: SurfaceCapabilitySnapshot
    ) -> Self {
        Self(
            dmabuf: dmabufStatus(capabilities.dmabuf),
            surfaceFeedback: surfaceFeedbackStatus(capabilities.dmabuf),
            renderNode: .unavailable,
            gbm: .unavailable,
            egl: .unavailable,
            dmabufImport: .unavailable,
            bufferLifecycle: .unavailable,
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
            tearingControl: capabilityStatus(
                capabilities.tearingControl,
                requested: false,
                missingReason: .presentationHintUnavailable
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
        snapshot.renderNode = .active
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
        snapshot.dmabufImport = .active
        snapshot.bufferLifecycle = .configured
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
        snapshot.tearingControl = capabilityStatus(
            capabilities.tearingControl,
            requested: metadata.presentationHint != nil,
            missingReason: .presentationHintUnavailable
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
        snapshot.surfaceFeedback = snapshot.surfaceFeedback.fallback(runtimeReason)
        snapshot.renderNode = snapshot.renderNode.fallback(runtimeReason)
        snapshot.gbm = .fallback(runtimeReason)
        snapshot.egl = .fallback(runtimeReason)
        snapshot.dmabufImport = snapshot.dmabufImport.fallback(runtimeReason)
        snapshot.bufferLifecycle = snapshot.bufferLifecycle.fallback(runtimeReason)
        if reason == .explicitSyncRequiredButUnavailable {
            snapshot.synchronization = .explicitFallback(runtimeReason)
        }
        if case .fifoRequiredButUnavailable = reason {
            snapshot.pacing = .fallback(runtimeReason)
        }
        if case .commitTimingRequiredButUnavailable = reason {
            snapshot.pacing = .fallback(runtimeReason)
        }
        if case .metadataRequiredButUnavailable(let error) = reason {
            markMetadataRequirementFallback(error, in: &snapshot)
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
        case .dmabufUnavailable:
            snapshot.dmabuf = .failed(runtimeReason)
        case .surfaceFeedbackUnavailable:
            snapshot.surfaceFeedback = snapshot.surfaceFeedback.failed(runtimeReason)
            snapshot.dmabuf = snapshot.dmabuf.failed(runtimeReason)
        case .compositorRejectedBuffer:
            snapshot.dmabufImport = snapshot.dmabufImport.failed(runtimeReason)
            snapshot.dmabuf = snapshot.dmabuf.failed(runtimeReason)
        case .noRenderNode:
            snapshot.renderNode = .failed(runtimeReason)
            snapshot.gbm = .failed(runtimeReason)
        case .noCompatibleFormat, .gbmUnavailable, .gbmAllocationFailed:
            snapshot.gbm = .failed(runtimeReason)
        case .eglUnavailable:
            snapshot.egl = .failed(runtimeReason)
        case .explicitSyncRequiredButUnavailable, .submitConstraintRejected:
            snapshot.synchronization = .explicitFailed(runtimeReason)
        case .fifoRequiredButUnavailable, .commitTimingRequiredButUnavailable,
            .commitTimingRejected:
            snapshot.pacing = .failed(runtimeReason)
        case .metadataRequiredButUnavailable(let error):
            markMetadataRequirementFailure(error, in: &snapshot)
        case .commitFailed, .presentationTrackingFailed:
            snapshot.bufferLifecycle = snapshot.bufferLifecycle.failed(runtimeReason)
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
    // swiftlint:disable:next cyclomatic_complexity
    package init(_ fallbackReason: GPUFallbackReason) {
        switch fallbackReason {
        case .policyForcedSHM:
            self = .policyForcedSHM
        case .dmabufUnavailable:
            self = .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            self = .surfaceFeedbackUnavailable
        case .noCompatibleFormat:
            self = .noCompatibleFormat
        case .noRenderNode:
            self = .noRenderNode
        case .gbmAllocationFailed:
            self = .gbmAllocationFailed
        case .explicitSyncRequiredButUnavailable:
            self = .explicitSynchronizationUnavailable
        case .fifoRequiredButUnavailable:
            self = .fifoUnavailable
        case .commitTimingRequiredButUnavailable:
            self = .commitTimingUnavailable
        case .metadataRequiredButUnavailable(let error):
            self = GPURuntimePathReason(error)
        case .gbmUnavailable:
            self = .gbmUnavailable
        case .eglUnavailable:
            self = .eglUnavailable
        case .compositorRejectedBuffer:
            self = .compositorRejectedBuffer
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    package init(_ failure: GPUBackingFailure) {
        switch failure {
        case .dmabufUnavailable:
            self = .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            self = .surfaceFeedbackUnavailable
        case .noCompatibleFormat:
            self = .noCompatibleFormat
        case .noRenderNode:
            self = .noRenderNode
        case .gbmAllocationFailed:
            self = .gbmAllocationFailed
        case .explicitSyncRequiredButUnavailable, .submitConstraintRejected:
            self = .explicitSynchronizationUnavailable
        case .fifoRequiredButUnavailable:
            self = .fifoUnavailable
        case .commitTimingRequiredButUnavailable, .commitTimingRejected:
            self =
                failure == .commitTimingRejected
                ? .commitTimingRejected
                : .commitTimingUnavailable
        case .metadataRequiredButUnavailable(let error):
            self = GPURuntimePathReason(error)
        case .gbmUnavailable:
            self = .gbmUnavailable
        case .eglUnavailable:
            self = .eglUnavailable
        case .compositorRejectedBuffer:
            self = .compositorRejectedBuffer
        case .commitFailed:
            self = .commitFailed
        case .presentationTrackingFailed:
            self = .presentationTrackingFailed
        }
    }

    package init(_ metadataError: SurfaceCommitMetadataError) {
        switch metadataError {
        case .contentTypeUnavailable, .contentTypeObjectUnavailable,
            .unsupportedContentType:
            self = .contentTypeUnavailable
        case .alphaModifierUnavailable, .alphaModifierObjectUnavailable:
            self = .alphaModifierUnavailable
        case .tearingControlUnavailable, .tearingControlObjectUnavailable:
            self = .presentationHintUnavailable
        case .colorRepresentationUnavailable, .colorRepresentationObjectUnavailable,
            .unsupportedAlphaMode, .unsupportedCoefficientsAndRange,
            .unsupportedChromaLocation:
            self = .colorRepresentationUnavailable
        case .colorRepresentationSupportPending:
            self = .colorRepresentationSupportPending
        case .colorUnavailable, .colorManagementObjectUnavailable,
            .colorDescriptionUnavailable, .colorDescriptionPending,
            .colorDescriptionFailed, .invalidColorDescriptionIdentity:
            self = .colorManagementUnavailable
        }
    }
}

private func markMetadataRequirementFallback(
    _ error: SurfaceCommitMetadataError,
    in snapshot: inout GPURuntimePathSnapshot
) {
    markMetadataRequirement(
        error,
        status: .fallback(GPURuntimePathReason(error)),
        in: &snapshot
    )
}

private func markMetadataRequirementFailure(
    _ error: SurfaceCommitMetadataError,
    in snapshot: inout GPURuntimePathSnapshot
) {
    markMetadataRequirement(
        error,
        status: .failed(GPURuntimePathReason(error)),
        in: &snapshot
    )
}

private func markMetadataRequirement(
    _ error: SurfaceCommitMetadataError,
    status: RuntimePathStatus,
    in snapshot: inout GPURuntimePathSnapshot
) {
    switch metadataRuntimePathComponent(for: error) {
    case .contentType:
        snapshot.contentType = status
    case .alpha:
        snapshot.alpha = status
    case .tearingControl:
        snapshot.tearingControl = status
    case .colorRepresentation:
        snapshot.colorRepresentation = status
    case .colorManagement:
        snapshot.colorManagement = status
    }
}

private enum MetadataRuntimePathComponent {
    case contentType
    case alpha
    case tearingControl
    case colorRepresentation
    case colorManagement
}

private func metadataRuntimePathComponent(
    for error: SurfaceCommitMetadataError
) -> MetadataRuntimePathComponent {
    switch error {
    case .contentTypeUnavailable, .contentTypeObjectUnavailable,
        .unsupportedContentType:
        .contentType
    case .alphaModifierUnavailable, .alphaModifierObjectUnavailable:
        .alpha
    case .tearingControlUnavailable, .tearingControlObjectUnavailable:
        .tearingControl
    case .colorRepresentationUnavailable, .colorRepresentationObjectUnavailable,
        .colorRepresentationSupportPending, .unsupportedAlphaMode,
        .unsupportedCoefficientsAndRange, .unsupportedChromaLocation:
        .colorRepresentation
    case .colorUnavailable, .colorManagementObjectUnavailable,
        .colorDescriptionUnavailable, .colorDescriptionPending,
        .colorDescriptionFailed, .invalidColorDescriptionIdentity:
        .colorManagement
    }
}
