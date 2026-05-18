import Testing
import WaylandRaw

@testable import WaylandClient

struct SurfaceSubmitConstraintsTests {
    private let activeCapabilities = SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .unavailable,
        dmabuf: .unavailable,
        synchronization: .explicitActive,
        pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
    )

    @Test
    func defaultConstraintsValidateForImplicitSurface() throws {
        let capabilities = SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .unavailable
        )

        try SurfaceSubmitConstraints.default.validate(
            capabilities: capabilities,
            attachesBuffer: true
        )
    }

    @Test
    func explicitSyncRequiresActiveSurfaceObject() throws {
        let constraints = SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: nil,
                release: syncPoint(timeline: 1, point: 1)
            ),
            pacing: .none
        )
        let capabilities = SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .explicitAvailable(version: 1),
            pacing: .unavailable
        )

        #expect(throws: SurfaceSubmitConstraintError.explicitSyncUnavailable) {
            try constraints.validate(capabilities: capabilities, attachesBuffer: true)
        }
    }

    @Test
    func explicitSyncRequiresReleasePointForBufferCommit() throws {
        let constraints = SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: syncPoint(timeline: 1, point: 1),
                release: nil
            ),
            pacing: .none
        )

        #expect(throws: SurfaceSubmitConstraintError.releasePointRequired) {
            try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
        }
    }

    @Test
    func explicitSyncRejectsPointsWithoutBufferCommit() throws {
        let acquireOnly = SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: syncPoint(timeline: 1, point: 1),
                release: nil
            ),
            pacing: .none
        )
        let releaseOnly = SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: nil,
                release: syncPoint(timeline: 1, point: 1)
            ),
            pacing: .none
        )

        #expect(throws: SurfaceSubmitConstraintError.acquirePointWithoutAttachedBuffer) {
            try acquireOnly.validate(capabilities: activeCapabilities, attachesBuffer: false)
        }
        #expect(throws: SurfaceSubmitConstraintError.releasePointWithoutAttachedBuffer) {
            try releaseOnly.validate(capabilities: activeCapabilities, attachesBuffer: false)
        }
    }

    @Test
    func explicitSyncRejectsConflictingPointsOnSameTimeline() throws {
        let constraints = SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: syncPoint(timeline: 7, point: 9),
                release: syncPoint(timeline: 7, point: 9)
            ),
            pacing: .none
        )

        #expect(throws: SurfaceSubmitConstraintError.conflictingSyncPoints) {
            try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
        }
    }

    @Test
    func fifoRequiresFifoCapability() throws {
        let constraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: .fifo(.waitBarrier)
        )
        let capabilities = SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .commitTiming(version: 1)
        )

        #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
            try constraints.validate(capabilities: capabilities, attachesBuffer: true)
        }
    }

    @Test
    func commitTimingRequiresCommitTimingCapability() throws {
        let target = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
        let constraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: .targetTime(target)
        )
        let capabilities = SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .fifo(version: 1)
        )

        #expect(throws: SurfaceSubmitConstraintError.commitTimingUnavailable) {
            try constraints.validate(capabilities: capabilities, attachesBuffer: true)
        }
    }

    @Test
    func commitTargetTimeRejectsInvalidNanoseconds() {
        #expect(throws: SurfaceSubmitConstraintError.invalidCommitTimestamp) {
            _ = try SurfaceCommitTargetTime(seconds: 0, nanoseconds: 1_000_000_000)
        }
    }

    @Test
    func fifoAndCommitTimingValidateWhenBothAreAvailable() throws {
        let target = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
        let constraints = SurfaceSubmitConstraints(
            synchronization: .implicit,
            pacing: .fifoAndTargetTime(.setBarrier, target)
        )

        try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
    }

    private func syncPoint(timeline: UInt64, point: UInt64) -> SurfaceSyncPoint {
        SurfaceSyncPoint(
            timeline: SurfaceSyncTimelineIdentity(timeline),
            point: RawSyncobjTimelinePoint(point)
        )
    }
}

