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
    func surfaceDestroyedPhaseKeepsOnlyRetiredBufferList() {
        var runtime = SurfaceRuntime<RoleToken>()

        runtime.markSurfaceDestroyed()
        runtime.retiredBufferPools = []
        runtime.buffers = nil
        runtime.roleResources = nil

        #expect(runtime.retiredBufferPools.isEmpty)
        #expect(runtime.buffers == nil)
        #expect(runtime.roleResources == nil)
    }
}
