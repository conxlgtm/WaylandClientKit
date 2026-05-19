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
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.submitConstraintObjects.hasExplicitSynchronization
        case .surfaceDestroyed:
            false
        }
    }

    var hasFifoObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.submitConstraintObjects.hasFifo
        case .surfaceDestroyed:
            false
        }
    }

    var hasCommitTimerObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.submitConstraintObjects.hasCommitTimer
        case .surfaceDestroyed:
            false
        }
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
        switch phase {
        case .unassigned(var objects):
            try objects.submitConstraintObjects.apply(constraints)
            phase = .unassigned(objects)
        case .live(let roleResources, var objects):
            try objects.submitConstraintObjects.apply(constraints)
            phase = .live(roleResources: roleResources, objects)
        case .roleDestroyed(var objects):
            try objects.submitConstraintObjects.apply(constraints)
            phase = .roleDestroyed(objects)
        case .surfaceDestroyed:
            return
        }
    }

    mutating func markSubmitConstraintsCommitted() {
        updateSurfaceObjects { objects in
            objects.submitConstraintObjects.markCommitted()
        }
    }
}
