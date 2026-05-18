import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct SurfaceRuntimeSubmitTests {
    struct RoleToken: Equatable {}

    @Test
    func submitCapabilitySnapshotPublishesSynchronizationAndPacingFacts() {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        runtime.setSynchronizationCapability(.explicitAvailable(version: 1))
        runtime.setPacingCapability(.fifoAndCommitTiming(fifo: 1, commitTiming: 1))

        let snapshot = runtime.capabilitySnapshot()

        #expect(snapshot.synchronization == .explicitAvailable(version: 1))
        #expect(snapshot.pacing == .fifoAndCommitTiming(fifo: 1, commitTiming: 1))
    }

    @Test
    func activatingExplicitSynchronizationUpdatesCapabilitySnapshot() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        runtime.setSynchronizationCapability(.explicitAvailable(version: 1))
        runtime.setExplicitSynchronizationActive()

        #expect(runtime.capabilitySnapshot().synchronization == .explicitActive)
    }

    @Test
    func missingSubmitConstraintObjectsRejectNonDefaultConstraints() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
        let syncPoint = SurfaceSyncPoint(
            timeline: SurfaceSyncTimelineIdentity(1),
            point: RawSyncobjTimelinePoint(2)
        )
        let targetTime = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)

        runtime.setExplicitSynchronizationActive()
        runtime.setPacingCapability(.fifoAndCommitTiming(fifo: 1, commitTiming: 1))

        #expect(throws: SurfaceSubmitConstraintError.explicitSyncUnavailable) {
            try runtime.applySubmitConstraints(
                SurfaceSubmitConstraints(
                    synchronization: .explicit(acquire: nil, release: syncPoint),
                    pacing: .none
                )
            )
        }
        #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
            try runtime.applySubmitConstraints(
                SurfaceSubmitConstraints(
                    synchronization: .implicit,
                    pacing: .fifo(.waitBarrier)
                )
            )
        }
        #expect(throws: SurfaceSubmitConstraintError.commitTimingUnavailable) {
            try runtime.applySubmitConstraints(
                SurfaceSubmitConstraints(
                    synchronization: .implicit,
                    pacing: .targetTime(targetTime)
                )
            )
        }
    }

    @Test
    func missingSyncTimelineRejectsExplicitConstraintApplication() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
        let syncSurface = try StubSyncobjSurface()
        let syncPoint = SurfaceSyncPoint(
            timeline: SurfaceSyncTimelineIdentity(77),
            point: RawSyncobjTimelinePoint(2)
        )

        runtime.installExplicitSynchronizationObject(syncSurface.object)

        #expect(
            throws: SurfaceSubmitConstraintError.syncTimelineUnavailable(
                SurfaceSyncTimelineIdentity(77)
            )
        ) {
            try runtime.applySubmitConstraints(
                SurfaceSubmitConstraints(
                    synchronization: .explicit(acquire: nil, release: syncPoint),
                    pacing: .none
                )
            )
        }
    }
}

private final class StubSyncobjSurface {
    let object: RawLinuxDrmSyncobjSurface

    init() throws {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: 0x5501))
        object = RawLinuxDrmSyncobjSurface(pointer: pointer) {
            unsafe _ = $0
        }
    }
}
