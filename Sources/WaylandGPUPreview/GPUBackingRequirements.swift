import WaylandClient

package struct GPUBackingRequirements: Equatable, Sendable {
    package var synchronization: GPUBufferSubmissionSynchronization
    package var pacing: SurfacePacingConstraint
    package var metadata: SurfaceCommitMetadata

    package static let `default` = Self()

    package init(
        synchronization submissionSynchronization: GPUBufferSubmissionSynchronization = .implicit,
        pacing framePacing: SurfacePacingConstraint = .none,
        metadata commitMetadata: SurfaceCommitMetadata = .default
    ) {
        synchronization = submissionSynchronization
        pacing = framePacing
        metadata = commitMetadata
    }

    package func validate(
        capabilities: SurfaceCapabilitySnapshot
    ) throws(GPUBackingRequirementError) {
        if case .explicit = synchronization,
            !capabilities.synchronization.supportsExplicit
        {
            throw .explicitSyncUnavailable
        }

        switch pacing {
        case .none:
            break
        case .fifo:
            guard capabilities.pacing.supportsFifo else {
                throw .fifoUnavailable
            }
        case .targetTime:
            guard capabilities.pacing.supportsCommitTiming else {
                throw .commitTimingUnavailable
            }
        case .fifoAndTargetTime:
            guard capabilities.pacing.supportsFifo else {
                throw .fifoUnavailable
            }
            guard capabilities.pacing.supportsCommitTiming else {
                throw .commitTimingUnavailable
            }
        }

        do {
            try metadata.validate(capabilities: capabilities)
        } catch {
            throw .metadataUnavailable(error)
        }
    }
}

package enum GPUBackingRequirementError: Error, Equatable, Sendable {
    case explicitSyncUnavailable
    case fifoUnavailable
    case commitTimingUnavailable
    case metadataUnavailable(SurfaceCommitMetadataError)
}
