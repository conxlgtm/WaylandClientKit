import WaylandClient
import WaylandGraphicsCore

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
        requirements: GPUBackingRequirements = .default
    ) -> GPUBackingDecision {
        if self == .forceSHM {
            return .shm(.policyForcedSHM)
        }

        if case .unavailable = capabilities.dmabuf {
            return unavailableOrFallback(.dmabufUnavailable)
        }

        do {
            try requirements.validate(capabilities: capabilities)
        } catch {
            switch error {
            case .explicitSyncUnavailable:
                return unavailableOrFallback(.explicitSyncRequiredButUnavailable)
            case .fifoUnavailable:
                return unavailableOrFallback(.fifoRequiredButUnavailable)
            case .commitTimingUnavailable:
                return unavailableOrFallback(.commitTimingRequiredButUnavailable)
            case .metadataUnavailable(let metadataError):
                return unavailableOrFallback(
                    .metadataRequiredButUnavailable(metadataError)
                )
            }
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
    case fifoRequiredButUnavailable
    case commitTimingRequiredButUnavailable
    case metadataRequiredButUnavailable(SurfaceCommitMetadataError)
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
        case .fifoRequiredButUnavailable:
            "FIFO pacing was required but unavailable"
        case .commitTimingRequiredButUnavailable:
            "commit timing was required but unavailable"
        case .metadataRequiredButUnavailable(let error):
            "required surface metadata was unavailable: \(error.description)"
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
    case fifoRequiredButUnavailable
    case commitTimingRequiredButUnavailable
    case metadataRequiredButUnavailable(SurfaceCommitMetadataError)
    case compositorRejectedBuffer
    case submitConstraintRejected
    case commitFailed

    package init(_ fallbackReason: GPUFallbackReason) {
        if let failure = Self.platformFailure(for: fallbackReason)
            ?? Self.requirementFailure(for: fallbackReason)
            ?? Self.compositorFailure(for: fallbackReason)
        {
            self = failure
            return
        }

        preconditionFailure("policy-forced SHM is not a GPU backing failure")
    }

    private static func platformFailure(
        for fallbackReason: GPUFallbackReason
    ) -> Self? {
        switch fallbackReason {
        case .dmabufUnavailable:
            .dmabufUnavailable
        case .noCompatibleFormat:
            .noCompatibleFormat
        case .noRenderNode:
            .noRenderNode
        case .gbmUnavailable:
            .gbmUnavailable
        case .eglUnavailable:
            .eglUnavailable
        default:
            nil
        }
    }

    private static func requirementFailure(
        for fallbackReason: GPUFallbackReason
    ) -> Self? {
        switch fallbackReason {
        case .explicitSyncRequiredButUnavailable:
            .explicitSyncRequiredButUnavailable
        case .fifoRequiredButUnavailable:
            .fifoRequiredButUnavailable
        case .commitTimingRequiredButUnavailable:
            .commitTimingRequiredButUnavailable
        case .metadataRequiredButUnavailable(let error):
            .metadataRequiredButUnavailable(error)
        default:
            nil
        }
    }

    private static func compositorFailure(
        for fallbackReason: GPUFallbackReason
    ) -> Self? {
        switch fallbackReason {
        case .compositorRejectedBuffer:
            .compositorRejectedBuffer
        default:
            nil
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
        case .fifoRequiredButUnavailable:
            "FIFO pacing was required but unavailable"
        case .commitTimingRequiredButUnavailable:
            "commit timing was required but unavailable"
        case .metadataRequiredButUnavailable(let error):
            "required surface metadata was unavailable: \(error.description)"
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
        if oldMetadata.contentType != newMetadata.contentType
            || oldMetadata.alpha != newMetadata.alpha
            || oldMetadata.colorRepresentation != newMetadata.colorRepresentation
            || oldMetadata.colorDescription != newMetadata.colorDescription
            || oldSnapshot.contentType != newSnapshot.contentType
            || oldSnapshot.alphaModifier != newSnapshot.alphaModifier
            || oldSnapshot.color != newSnapshot.color
            || oldSnapshot.colorRepresentation != newSnapshot.colorRepresentation
        {
            changes.append(.colorMetadataChanged)
        }
        if oldMetadata.presentationHint != newMetadata.presentationHint
            || oldPacing != newPacing
            || oldSnapshot.pacing != newSnapshot.pacing
            || oldSnapshot.tearingControl != newSnapshot.tearingControl
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
