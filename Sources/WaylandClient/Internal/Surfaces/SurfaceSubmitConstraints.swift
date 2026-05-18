import WaylandRaw

package struct SurfaceSyncTimelineIdentity: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(_ identity: UInt64) {
        rawValue = identity
    }
}

package struct SurfaceSyncPoint: Equatable, Sendable {
    package let timeline: SurfaceSyncTimelineIdentity
    package let point: RawSyncobjTimelinePoint

    package init(
        timeline syncTimeline: SurfaceSyncTimelineIdentity,
        point syncPoint: RawSyncobjTimelinePoint
    ) {
        timeline = syncTimeline
        point = syncPoint
    }
}

package enum SurfaceSynchronizationConstraint: Equatable, Sendable {
    case implicit
    case explicit(acquire: SurfaceSyncPoint?, release: SurfaceSyncPoint?)
}

package enum FifoMode: Equatable, Sendable {
    case setBarrier
    case waitBarrier
}

package struct SurfaceCommitTargetTime: Equatable, Sendable {
    package static let maximumNanosecondValue: UInt32 = 999_999_999

    package let seconds: UInt64
    package let nanoseconds: UInt32

    package init(seconds targetSeconds: UInt64, nanoseconds targetNanoseconds: UInt32)
        throws(SurfaceSubmitConstraintError)
    {
        guard targetNanoseconds <= Self.maximumNanosecondValue else {
            throw SurfaceSubmitConstraintError.invalidCommitTimestamp
        }

        seconds = targetSeconds
        nanoseconds = targetNanoseconds
    }

    package var rawTargetTime: RawCommitTargetTime {
        get throws {
            try RawCommitTargetTime(seconds: seconds, nanoseconds: nanoseconds)
        }
    }
}

package enum SurfacePacingConstraint: Equatable, Sendable {
    case none
    case fifo(FifoMode)
    case targetTime(SurfaceCommitTargetTime)
    case fifoAndTargetTime(FifoMode, SurfaceCommitTargetTime)
}

package struct SurfaceSubmitConstraints: Equatable, Sendable {
    package static let `default` = Self(
        synchronization: .implicit,
        pacing: .none
    )

    package var synchronization: SurfaceSynchronizationConstraint
    package var pacing: SurfacePacingConstraint

    package init(
        synchronization submitSynchronization: SurfaceSynchronizationConstraint,
        pacing submitPacing: SurfacePacingConstraint
    ) {
        synchronization = submitSynchronization
        pacing = submitPacing
    }

    package func validate(
        capabilities: SurfaceCapabilitySnapshot,
        attachesBuffer: Bool
    ) throws(SurfaceSubmitConstraintError) {
        try validateSynchronization(
            capabilities.synchronization,
            attachesBuffer: attachesBuffer
        )
        try validatePacing(capabilities.pacing)
    }

    private func validateSynchronization(
        _ capability: SurfaceSynchronizationCapability,
        attachesBuffer: Bool
    ) throws(SurfaceSubmitConstraintError) {
        switch synchronization {
        case .implicit:
            if capability == .explicitActive, attachesBuffer {
                throw SurfaceSubmitConstraintError.explicitSyncRequired
            }
            return
        case .explicit(let acquire, let release):
            guard capability == .explicitActive else {
                throw SurfaceSubmitConstraintError.explicitSyncUnavailable
            }

            guard attachesBuffer else {
                if acquire != nil {
                    throw SurfaceSubmitConstraintError.acquirePointWithoutAttachedBuffer
                }
                if release != nil {
                    throw SurfaceSubmitConstraintError.releasePointWithoutAttachedBuffer
                }
                return
            }

            guard let acquire else {
                throw SurfaceSubmitConstraintError.acquirePointRequired
            }

            guard let release else {
                throw SurfaceSubmitConstraintError.releasePointRequired
            }

            try validateOrdering(acquire: acquire, release: release)
        }
    }

    private func validateOrdering(
        acquire: SurfaceSyncPoint,
        release: SurfaceSyncPoint
    ) throws(SurfaceSubmitConstraintError) {
        guard acquire.timeline == release.timeline else {
            return
        }

        guard acquire.point.rawValue < release.point.rawValue else {
            throw SurfaceSubmitConstraintError.conflictingSyncPoints
        }
    }

    private func validatePacing(
        _ capability: SurfacePacingCapability
    ) throws(SurfaceSubmitConstraintError) {
        switch pacing {
        case .none:
            return
        case .fifo:
            guard capability.supportsFifo else {
                throw SurfaceSubmitConstraintError.fifoUnavailable
            }
        case .targetTime:
            guard capability.supportsCommitTiming else {
                throw SurfaceSubmitConstraintError.commitTimingUnavailable
            }
        case .fifoAndTargetTime:
            guard capability.supportsFifo else {
                throw SurfaceSubmitConstraintError.fifoUnavailable
            }
            guard capability.supportsCommitTiming else {
                throw SurfaceSubmitConstraintError.commitTimingUnavailable
            }
        }
    }
}

package enum SurfaceSubmitConstraintError: Error, Equatable, Sendable {
    case explicitSyncUnavailable
    case explicitSyncRequired
    case acquirePointRequired
    case releasePointRequired
    case acquirePointWithoutAttachedBuffer
    case releasePointWithoutAttachedBuffer
    case conflictingSyncPoints
    case fifoUnavailable
    case commitTimingUnavailable
    case invalidCommitTimestamp
    case syncTimelineUnavailable(SurfaceSyncTimelineIdentity)
}
