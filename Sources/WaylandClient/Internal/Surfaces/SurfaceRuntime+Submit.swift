import WaylandRaw

extension SurfaceRuntime {
    mutating func setSynchronizationCapability(
        _ capability: SurfaceSynchronizationCapability
    ) {
        synchronizationCapability = capability
    }

    mutating func setExplicitSynchronizationActive() {
        synchronizationCapability = .explicitActive
    }

    mutating func setPacingCapability(_ capability: SurfacePacingCapability) {
        pacingCapability = capability
    }

    var hasExplicitSynchronizationObject: Bool {
        surfaceObjects?.submitConstraintObjects.hasExplicitSynchronization ?? false
    }

    var hasFifoObject: Bool {
        surfaceObjects?.submitConstraintObjects.hasFifo ?? false
    }

    var hasCommitTimerObject: Bool {
        surfaceObjects?.submitConstraintObjects.hasCommitTimer ?? false
    }

    mutating func installExplicitSynchronizationObject(
        _ syncobjSurface: RawLinuxDrmSyncobjSurface
    ) {
        synchronizationCapability = .explicitActive
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.installSynchronization(syncobjSurface)
        }
    }

    mutating func installSynchronizationTimeline(
        _ timeline: RawLinuxDrmSyncobjTimeline,
        identity: SurfaceSyncTimelineIdentity
    ) {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.installTimeline(timeline, identity: identity)
        }
    }

    mutating func removeSynchronizationTimeline(
        identity: SurfaceSyncTimelineIdentity
    ) {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.removeTimeline(identity: identity)
        }
    }

    mutating func installFifoObject(_ fifo: RawFifo) {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.installFifo(fifo)
        }
    }

    mutating func installCommitTimerObject(_ timer: RawCommitTimer) {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.installCommitTimer(timer)
        }
    }

    mutating func applySubmitConstraints(
        _ constraints: SurfaceSubmitConstraints
    ) throws(SurfaceSubmitConstraintError) {
        try updateSurfaceObjects { objects throws(SurfaceSubmitConstraintError) in
            try objects.submitConstraintObjects.apply(constraints)
        }
    }

    mutating func markSubmitConstraintsCommitted() {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.markCommitted()
        }
    }
}
