import WaylandClient
import WaylandGraphicsPreview

package struct GPUWindowBackingState: Equatable, Sendable {
    package var lifecycle: GPUWindowBackingLifecycle
    package var runtimePath: GPURuntimePathSnapshot
    package var surfaceCapabilities: SurfaceCapabilitySnapshot?
    package var bufferPool: GPUBufferPoolReadiness
    package var lastSubmittedFrame: GPUWindowPresentedFrame?
    package var diagnostics: [GPUBackingDiagnostic]

    package static let unconfigured = Self(
        lifecycle: .unconfigured,
        runtimePath: .empty,
        surfaceCapabilities: nil,
        bufferPool: .unconfigured,
        lastSubmittedFrame: nil,
        diagnostics: []
    )

    package mutating func recordCapabilities(
        _ capabilities: SurfaceCapabilitySnapshot
    ) {
        surfaceCapabilities = capabilities
        runtimePath = .afterCapabilityDiscovery(capabilities: capabilities)
        lifecycle = .configuring
    }

    package mutating func markReady(
        runtimePath newRuntimePath: GPURuntimePathSnapshot,
        capabilities: SurfaceCapabilitySnapshot,
        bufferPool newBufferPool: GPUBufferPoolReadiness,
        frame: GPUWindowPresentedFrame?
    ) {
        lifecycle = .ready
        runtimePath = newRuntimePath
        surfaceCapabilities = capabilities
        bufferPool = newBufferPool
        lastSubmittedFrame = frame
    }

    package mutating func markFallback(
        _ reason: GPUFallbackReason,
        capabilities: SurfaceCapabilitySnapshot? = nil
    ) {
        lifecycle = .fallbackToSHM(reason)
        if let capabilities {
            surfaceCapabilities = capabilities
            runtimePath = .afterFallback(capabilities: capabilities, reason: reason)
        }
        diagnostics.append(
            GPUBackingDiagnostic(
                operation: .fallbackSelection,
                severity: .warning,
                payload: .fallbackSelected(reason)
            )
        )
    }

    package mutating func markFailed(
        _ failure: GPUBackingFailure,
        operation: GPUBackingOperation
    ) {
        lifecycle = .failed(failure)
        if let surfaceCapabilities {
            runtimePath = .afterFailure(capabilities: surfaceCapabilities, failure: failure)
        }
        diagnostics.append(
            GPUBackingDiagnostic(
                operation: operation,
                severity: .error,
                payload: .failure(failure)
            )
        )
    }

    package mutating func markRetired() {
        lifecycle = .retired
        bufferPool = .retired
        lastSubmittedFrame = nil
    }
}

package enum GPUWindowBackingLifecycle: Equatable, Sendable {
    case unconfigured
    case configuring
    case ready
    case fallbackToSHM(GPUFallbackReason)
    case failed(GPUBackingFailure)
    case retired
}

package enum GPUBufferPoolReadiness: Equatable, Sendable {
    case unconfigured
    case empty
    case ready(installedSlots: Int, availableSlots: Int, submittedSlots: Int)
    case exhausted(installedSlots: Int, submittedSlots: Int)
    case retired
}

package enum GPUFallbackPolicy: Equatable, Sendable {
    case preferGPUFallbackToSHM
    case requireGPU
    case forceSHM

    package func decide(
        capabilities: SurfaceCapabilitySnapshot,
        requiresExplicitSynchronization: Bool = false,
        requiresMetadata: Bool = false
    ) -> GPUBackingDecision {
        if self == .forceSHM {
            return .shm(.policyForcedSHM)
        }

        if case .unavailable = capabilities.dmabuf {
            return unavailableOrFallback(.dmabufUnavailable)
        }

        if requiresExplicitSynchronization,
            !capabilities.synchronization.supportsExplicit
        {
            return unavailableOrFallback(.explicitSyncRequiredButUnavailable)
        }

        if requiresMetadata,
            !capabilities.supportsAnyMetadata
        {
            return unavailableOrFallback(.metadataRequiredButUnavailable)
        }

        return .gpu(
            GPUWindowBackingState(
                lifecycle: .configuring,
                runtimePath: .afterCapabilityDiscovery(capabilities: capabilities),
                surfaceCapabilities: capabilities,
                bufferPool: .empty,
                lastSubmittedFrame: nil,
                diagnostics: []
            )
        )
    }

    private func unavailableOrFallback(
        _ reason: GPUFallbackReason
    ) -> GPUBackingDecision {
        switch self {
        case .preferGPUFallbackToSHM, .forceSHM:
            .shm(reason)
        case .requireGPU:
            .unavailable(GPUBackingFailure(reason))
        }
    }
}

package enum GPUBackingDecision: Equatable, Sendable {
    case gpu(GPUWindowBackingState)
    case shm(GPUFallbackReason)
    case unavailable(GPUBackingFailure)
}

package enum GPUFallbackReason: Equatable, Sendable, CustomStringConvertible {
    case policyForcedSHM
    case dmabufUnavailable
    case noCompatibleFormat
    case noRenderNode
    case gbmUnavailable
    case eglUnavailable
    case explicitSyncRequiredButUnavailable
    case metadataRequiredButUnavailable
    case compositorRejectedBuffer

    package var description: String {
        switch self {
        case .policyForcedSHM:
            "SHM was forced by policy"
        case .dmabufUnavailable:
            "linux-dmabuf is unavailable"
        case .noCompatibleFormat:
            "no compatible dmabuf format was found"
        case .noRenderNode:
            "no DRM render node was found"
        case .gbmUnavailable:
            "GBM is unavailable"
        case .eglUnavailable:
            "EGL is unavailable"
        case .explicitSyncRequiredButUnavailable:
            "explicit synchronization was required but unavailable"
        case .metadataRequiredButUnavailable:
            "required surface metadata was unavailable"
        case .compositorRejectedBuffer:
            "the compositor rejected the GPU buffer"
        }
    }
}

package enum GPUBackingFailure: Equatable, Sendable, CustomStringConvertible {
    case dmabufUnavailable
    case noCompatibleFormat
    case noRenderNode
    case gbmUnavailable
    case gbmAllocationFailed
    case eglUnavailable
    case explicitSyncRequiredButUnavailable
    case metadataRequiredButUnavailable
    case compositorRejectedBuffer
    case submitConstraintRejected
    case commitFailed

    package init(_ fallbackReason: GPUFallbackReason) {
        switch fallbackReason {
        case .policyForcedSHM:
            self = .dmabufUnavailable
        case .dmabufUnavailable:
            self = .dmabufUnavailable
        case .noCompatibleFormat:
            self = .noCompatibleFormat
        case .noRenderNode:
            self = .noRenderNode
        case .gbmUnavailable:
            self = .gbmUnavailable
        case .eglUnavailable:
            self = .eglUnavailable
        case .explicitSyncRequiredButUnavailable:
            self = .explicitSyncRequiredButUnavailable
        case .metadataRequiredButUnavailable:
            self = .metadataRequiredButUnavailable
        case .compositorRejectedBuffer:
            self = .compositorRejectedBuffer
        }
    }

    package var description: String {
        switch self {
        case .dmabufUnavailable:
            "linux-dmabuf is unavailable"
        case .noCompatibleFormat:
            "no compatible dmabuf format was found"
        case .noRenderNode:
            "no DRM render node was found"
        case .gbmUnavailable:
            "GBM is unavailable"
        case .gbmAllocationFailed:
            "GBM allocation failed"
        case .eglUnavailable:
            "EGL is unavailable"
        case .explicitSyncRequiredButUnavailable:
            "explicit synchronization was required but unavailable"
        case .metadataRequiredButUnavailable:
            "required surface metadata was unavailable"
        case .compositorRejectedBuffer:
            "the compositor rejected the GPU buffer"
        case .submitConstraintRejected:
            "submit constraints were rejected"
        case .commitFailed:
            "surface commit failed"
        }
    }
}

package struct GPUBackingInvalidation: Equatable, Sendable {
    package let reason: GPUBackingInvalidationReason
    package let oldSnapshot: SurfaceCapabilitySnapshot
    package let newSnapshot: SurfaceCapabilitySnapshot

    package init(
        reason invalidationReason: GPUBackingInvalidationReason,
        oldSnapshot previousSnapshot: SurfaceCapabilitySnapshot,
        newSnapshot nextSnapshot: SurfaceCapabilitySnapshot
    ) {
        reason = invalidationReason
        oldSnapshot = previousSnapshot
        newSnapshot = nextSnapshot
    }

    package static func changes(
        oldSnapshot: SurfaceCapabilitySnapshot,
        newSnapshot: SurfaceCapabilitySnapshot,
        oldGeometry: SurfaceGeometry? = nil,
        newGeometry: SurfaceGeometry? = nil,
        oldSynchronization: SurfaceSynchronizationCapability? = nil,
        newSynchronization: SurfaceSynchronizationCapability? = nil,
        oldMetadata: SurfaceCommitMetadata = .default,
        newMetadata: SurfaceCommitMetadata = .default,
        oldPacing: SurfacePacingCapability? = nil,
        newPacing: SurfacePacingCapability? = nil
    ) -> [GPUBackingInvalidation] {
        GPUBackingInvalidationReason.changes(
            oldSnapshot: oldSnapshot,
            newSnapshot: newSnapshot,
            oldGeometry: oldGeometry,
            newGeometry: newGeometry,
            oldSynchronization: oldSynchronization,
            newSynchronization: newSynchronization,
            oldMetadata: oldMetadata,
            newMetadata: newMetadata,
            oldPacing: oldPacing,
            newPacing: newPacing
        ).map { reason in
            GPUBackingInvalidation(
                reason: reason,
                oldSnapshot: oldSnapshot,
                newSnapshot: newSnapshot
            )
        }
    }
}

package enum GPUBackingInvalidationReason: Equatable, Sendable {
    case logicalSizeChanged
    case bufferScaleChanged
    case outputMembershipChanged
    case dmabufFeedbackChanged
    case formatModifierChanged
    case synchronizationModeChanged
    case colorMetadataChanged
    case presentationModeChanged

    package static func changes(
        oldSnapshot: SurfaceCapabilitySnapshot,
        newSnapshot: SurfaceCapabilitySnapshot,
        oldGeometry: SurfaceGeometry? = nil,
        newGeometry: SurfaceGeometry? = nil,
        oldSynchronization: SurfaceSynchronizationCapability? = nil,
        newSynchronization: SurfaceSynchronizationCapability? = nil,
        oldMetadata: SurfaceCommitMetadata = .default,
        newMetadata: SurfaceCommitMetadata = .default,
        oldPacing: SurfacePacingCapability? = nil,
        newPacing: SurfacePacingCapability? = nil
    ) -> [Self] {
        var changes: [Self] = []

        if oldGeometry?.logicalSize != newGeometry?.logicalSize {
            changes.append(.logicalSizeChanged)
        }
        if oldGeometry?.scale != newGeometry?.scale {
            changes.append(.bufferScaleChanged)
        }
        if oldSnapshot.outputIDs != newSnapshot.outputIDs {
            changes.append(.outputMembershipChanged)
        }
        if oldSnapshot.dmabuf != newSnapshot.dmabuf {
            changes.append(.dmabufFeedbackChanged)
        }
        if oldSynchronization != newSynchronization
            || oldSnapshot.synchronization != newSnapshot.synchronization
        {
            changes.append(.synchronizationModeChanged)
        }
        if oldMetadata.colorDescription != newMetadata.colorDescription
            || oldSnapshot.color != newSnapshot.color
            || oldSnapshot.colorRepresentation != newSnapshot.colorRepresentation
        {
            changes.append(.colorMetadataChanged)
        }
        if oldMetadata.presentationHint != newMetadata.presentationHint
            || oldPacing != newPacing
            || oldSnapshot.pacing != newSnapshot.pacing
            || oldSnapshot.presentationFeedback != newSnapshot.presentationFeedback
        {
            changes.append(.presentationModeChanged)
        }

        return changes
    }
}

package struct GPUBackingDiagnostic: Equatable, Sendable {
    package let operation: GPUBackingOperation
    package let severity: DiagnosticSeverity
    package let payload: GPUBackingDiagnosticPayload

    package init(
        operation diagnosticOperation: GPUBackingOperation,
        severity diagnosticSeverity: DiagnosticSeverity,
        payload diagnosticPayload: GPUBackingDiagnosticPayload
    ) {
        operation = diagnosticOperation
        severity = diagnosticSeverity
        payload = diagnosticPayload
    }
}

package enum GPUBackingOperation: Equatable, Sendable {
    case capabilityDiscovery
    case renderNodeSelection
    case formatSelection
    case gbmAllocation
    case eglSetup
    case dmabufImport
    case synchronizationSetup
    case metadataSetup
    case submitConstraintApplication
    case surfaceCommit
    case releaseTracking
    case fallbackSelection
}

package enum GPUBackingDiagnosticPayload: Equatable, Sendable {
    case dmabufFeedbackUnavailable
    case formatSelectionFailed
    case gbmAllocationFailed
    case eglSetupFailed
    case synchronizationSetupFailed
    case metadataSetupFailed
    case submitConstraintRejected
    case commitFailed
    case releaseSignalMissing(GBMBufferPoolSlotID)
    case fallbackSelected(GPUFallbackReason)
    case failure(GPUBackingFailure)
}

extension SurfaceSynchronizationCapability {
    package var supportsExplicit: Bool {
        switch self {
        case .implicitOnly:
            false
        case .explicitAvailable, .explicitActive:
            true
        }
    }
}

extension SurfaceCapabilitySnapshot {
    package var supportsAnyMetadata: Bool {
        contentType == .available
            || alphaModifier == .available
            || tearingControl == .available
            || colorRepresentation.isUsable
            || color.isUsable
    }
}

extension SurfaceColorRepresentationCapability {
    package var isUsable: Bool {
        guard case .available = self else { return false }
        return true
    }
}

extension SurfaceColorCapability {
    package var isUsable: Bool {
        switch self {
        case .unavailable:
            false
        case .available, .preferredDescription:
            true
        }
    }
}
