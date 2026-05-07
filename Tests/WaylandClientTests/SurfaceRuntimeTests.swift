import Testing

@testable import WaylandClient

@Suite
struct SurfaceRuntimeTests {
    private struct RoleToken: Equatable {
        let rawValue: Int
    }

    @Test
    func roleResourcesMoveIntoDestroyedRolePhase() {
        var runtime = SurfaceRuntime<RoleToken>()

        runtime.roleResources = RoleToken(rawValue: 1)

        #expect(runtime.roleResources == RoleToken(rawValue: 1))
        #expect(runtime.removeRoleResources() == RoleToken(rawValue: 1))
        #expect(runtime.roleResources == nil)
        #expect(runtime.removeRoleResources() == nil)
    }

    @Test
    func surfaceDestroyedPhaseKeepsOnlyRetiredBufferList() throws {
        var runtime = SurfaceRuntime<RoleToken>()

        try runtime.markSurfaceDestroyed()
        runtime.retiredBufferPools = []
        runtime.buffers = nil
        runtime.roleResources = nil

        #expect(runtime.retiredBufferPools.isEmpty)
        #expect(runtime.buffers == nil)
        #expect(runtime.roleResources == nil)
    }

    @Test
    func markSurfaceDestroyedRejectsLiveRoleResources() {
        var runtime = SurfaceRuntime<RoleToken>()

        runtime.roleResources = RoleToken(rawValue: 1)

        #expect(throws: SurfaceRuntimeError.surfaceDestroyedWithLiveRoleResources) {
            try runtime.markSurfaceDestroyed()
        }
        #expect(runtime.roleResources == RoleToken(rawValue: 1))
    }

    @Test
    func removedRoleResourcesAllowSurfaceDestruction() throws {
        var runtime = SurfaceRuntime<RoleToken>()

        runtime.roleResources = RoleToken(rawValue: 1)
        _ = runtime.removeRoleResources()

        try runtime.markSurfaceDestroyed()

        #expect(runtime.roleResources == nil)
        #expect(runtime.buffers == nil)
    }

    @Test
    func scaleInstallationUpdateAfterSurfaceDestructionIsIgnored() throws {
        var runtime = SurfaceRuntime<RoleToken>()
        var didRunUpdate = false

        try runtime.markSurfaceDestroyed()
        let result = runtime.updateScaleInstallation { _ in
            didRunUpdate = true
            return true
        }

        #expect(result == false)
        #expect(!didRunUpdate)
    }
}
