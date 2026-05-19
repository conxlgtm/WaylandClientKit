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
        try preflight(constraints).apply()
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

    func preflight(
        _ constraints: SurfaceSubmitConstraints
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfaceSubmitConstraints {
        ResolvedSurfaceSubmitConstraints(
            synchronization: try preflightSynchronization(
                constraints.synchronization
            ),
            pacing: try preflightPacing(constraints.pacing)
        )
    }

    private func preflightSynchronization(
        _ constraint: SurfaceSynchronizationConstraint
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfaceSynchronization? {
        switch constraint {
        case .implicit:
            return nil
        case .explicit(let acquire, let release):
            guard let synchronization else {
                throw .explicitSyncUnavailable
            }

            return ResolvedSurfaceSynchronization(
                object: synchronization,
                acquire: try acquire.map(resolve),
                release: try release.map(resolve)
            )
        }
    }

    private func preflightPacing(
        _ constraint: SurfacePacingConstraint
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfacePacing {
        switch constraint {
        case .none:
            return .none
        case .fifo(let mode):
            return ResolvedSurfacePacing(fifo: try preflightFifo(mode))
        case .targetTime(let targetTime):
            return ResolvedSurfacePacing(
                targetTime: try preflightCommitTargetTime(targetTime)
            )
        case .fifoAndTargetTime(let mode, let targetTime):
            return ResolvedSurfacePacing(
                fifo: try preflightFifo(mode),
                targetTime: try preflightCommitTargetTime(targetTime)
            )
        }
    }

    private func preflightFifo(
        _ mode: FifoMode
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfaceFifo {
        guard let fifo else {
            throw .fifoUnavailable
        }

        return ResolvedSurfaceFifo(object: fifo, mode: mode)
    }

    private func preflightCommitTargetTime(
        _ targetTime: SurfaceCommitTargetTime
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfaceCommitTargetTime {
        guard let commitTimer else {
            throw .commitTimingUnavailable
        }

        do {
            let rawTargetTime = try targetTime.rawTargetTime
            try commitTimer.validateCanSetTimestamp(rawTargetTime)
            return ResolvedSurfaceCommitTargetTime(
                object: commitTimer,
                targetTime: rawTargetTime
            )
        } catch RawCommitTimingError.invalidTimestamp {
            throw .invalidCommitTimestamp
        } catch RawCommitTimingError.timestampAlreadyExists {
            throw .commitTimestampAlreadyExists
        } catch {
            throw .commitTimingUnavailable
        }
    }

    private func resolve(
        _ point: SurfaceSyncPoint
    ) throws(SurfaceSubmitConstraintError) -> ResolvedSurfaceSyncPoint {
        try ResolvedSurfaceSyncPoint(
            timeline: timeline(for: point.timeline),
            point: point.point
        )
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

struct ResolvedSurfaceSubmitConstraints {
    let synchronization: ResolvedSurfaceSynchronization?
    let pacing: ResolvedSurfacePacing

    func apply() throws(SurfaceSubmitConstraintError) {
        try pacing.applyCommitTiming()
        synchronization?.apply()
        pacing.applyFifo()
    }
}

struct ResolvedSurfaceSynchronization {
    let object: RawLinuxDrmSyncobjSurface
    let acquire: ResolvedSurfaceSyncPoint?
    let release: ResolvedSurfaceSyncPoint?

    func apply() {
        if let acquire {
            object.setAcquirePoint(timeline: acquire.timeline, point: acquire.point)
        }
        if let release {
            object.setReleasePoint(timeline: release.timeline, point: release.point)
        }
    }
}

struct ResolvedSurfaceSyncPoint {
    let timeline: RawLinuxDrmSyncobjTimeline
    let point: RawSyncobjTimelinePoint
}

struct ResolvedSurfacePacing {
    static var none: Self {
        Self(fifo: nil, targetTime: nil)
    }

    let fifo: ResolvedSurfaceFifo?
    let targetTime: ResolvedSurfaceCommitTargetTime?

    init(
        fifo resolvedFifo: ResolvedSurfaceFifo? = nil,
        targetTime resolvedTargetTime: ResolvedSurfaceCommitTargetTime? = nil
    ) {
        fifo = resolvedFifo
        targetTime = resolvedTargetTime
    }

    func applyCommitTiming() throws(SurfaceSubmitConstraintError) {
        guard let targetTime else { return }

        do {
            try targetTime.object.setTimestamp(targetTime.targetTime)
        } catch RawCommitTimingError.invalidTimestamp {
            throw .invalidCommitTimestamp
        } catch RawCommitTimingError.timestampAlreadyExists {
            throw .commitTimestampAlreadyExists
        } catch {
            throw .commitTimingUnavailable
        }
    }

    func applyFifo() {
        guard let fifo else { return }

        switch fifo.mode {
        case .setBarrier:
            fifo.object.apply(.setBarrier)
        case .waitBarrier:
            fifo.object.apply(.waitBarrier)
        }
    }
}

struct ResolvedSurfaceFifo {
    let object: RawFifo
    let mode: FifoMode
}

struct ResolvedSurfaceCommitTargetTime {
    let object: RawCommitTimer
    let targetTime: RawCommitTargetTime
}
