import WaylandRaw

struct SurfaceSubmitConstraintObjects {
    private var synchronization: RawLinuxDrmSyncobjSurface?
    private var timelines: [SurfaceSyncTimelineIdentity: RawLinuxDrmSyncobjTimeline] = [:]
    private var fifo: RawFifo?
    private var commitTimer: RawCommitTimer?

    var hasExplicitSynchronization: Bool {
        synchronization != nil
    }

    var hasFifo: Bool {
        fifo != nil
    }

    var hasCommitTimer: Bool {
        commitTimer != nil
    }

    mutating func installSynchronization(_ syncobjSurface: RawLinuxDrmSyncobjSurface) {
        synchronization?.destroy()
        synchronization = syncobjSurface
    }

    mutating func installTimeline(
        _ timeline: RawLinuxDrmSyncobjTimeline,
        identity: SurfaceSyncTimelineIdentity
    ) {
        timelines[identity]?.destroy()
        timelines[identity] = timeline
    }

    mutating func installFifo(_ newFifo: RawFifo) {
        fifo?.destroy()
        fifo = newFifo
    }

    mutating func installCommitTimer(_ newCommitTimer: RawCommitTimer) {
        commitTimer?.destroy()
        commitTimer = newCommitTimer
    }

    mutating func apply(
        _ constraints: SurfaceSubmitConstraints
    ) throws(SurfaceSubmitConstraintError) {
        try applySynchronization(constraints.synchronization)
        try applyPacing(constraints.pacing)
    }

    mutating func markCommitted() {
        commitTimer?.markCommitted()
    }

    mutating func destroy() {
        commitTimer?.destroy()
        commitTimer = nil

        fifo?.destroy()
        fifo = nil

        for timeline in timelines.values {
            timeline.destroy()
        }
        timelines.removeAll(keepingCapacity: false)

        synchronization?.destroy()
        synchronization = nil
    }

    private func applySynchronization(
        _ constraint: SurfaceSynchronizationConstraint
    ) throws(SurfaceSubmitConstraintError) {
        switch constraint {
        case .implicit:
            return
        case .explicit(let acquire, let release):
            guard let synchronization else {
                throw .explicitSyncUnavailable
            }

            if let acquire {
                try synchronization.setAcquirePoint(
                    timeline: timeline(for: acquire.timeline),
                    point: acquire.point
                )
            }
            if let release {
                try synchronization.setReleasePoint(
                    timeline: timeline(for: release.timeline),
                    point: release.point
                )
            }
        }
    }

    private func applyPacing(
        _ constraint: SurfacePacingConstraint
    ) throws(SurfaceSubmitConstraintError) {
        switch constraint {
        case .none:
            return
        case .fifo(let mode):
            try applyFifo(mode)
        case .targetTime(let targetTime):
            try setCommitTargetTime(targetTime)
        case .fifoAndTargetTime(let mode, let targetTime):
            try applyFifo(mode)
            try setCommitTargetTime(targetTime)
        }
    }

    private func applyFifo(_ mode: FifoMode) throws(SurfaceSubmitConstraintError) {
        guard let fifo else {
            throw .fifoUnavailable
        }

        switch mode {
        case .setBarrier:
            fifo.apply(.setBarrier)
        case .waitBarrier:
            fifo.apply(.waitBarrier)
        }
    }

    private func setCommitTargetTime(
        _ targetTime: SurfaceCommitTargetTime
    ) throws(SurfaceSubmitConstraintError) {
        guard let commitTimer else {
            throw .commitTimingUnavailable
        }

        do {
            try commitTimer.setTimestamp(try targetTime.rawTargetTime)
        } catch RawCommitTimingError.invalidTimestamp {
            throw .invalidCommitTimestamp
        } catch {
            throw .commitTimingUnavailable
        }
    }

    private func timeline(
        for identity: SurfaceSyncTimelineIdentity
    ) throws(SurfaceSubmitConstraintError) -> RawLinuxDrmSyncobjTimeline {
        guard let timeline = timelines[identity] else {
            throw .syncTimelineUnavailable(identity)
        }

        return timeline
    }
}
