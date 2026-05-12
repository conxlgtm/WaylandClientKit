import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct SurfaceRuntimeTests {
    private struct RoleToken: Equatable {
        let rawValue: Int
    }

    @Test
    func roleResourcesMoveIntoDestroyedRolePhase() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        try runtime.installRoleResources(RoleToken(rawValue: 1))

        #expect(runtime.roleResources == RoleToken(rawValue: 1))
        #expect(runtime.removeRoleResources() == RoleToken(rawValue: 1))
        #expect(runtime.roleResources == nil)
        #expect(runtime.removeRoleResources() == nil)
    }

    @Test
    func surfaceDestroyedPhaseKeepsOnlyRetiredBufferList() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        try runtime.markSurfaceDestroyed()
        runtime.retiredBufferPools = []
        runtime.buffers = nil
        runtime.roleResources = nil

        #expect(runtime.retiredBufferPools.isEmpty)
        #expect(runtime.buffers == nil)
        #expect(runtime.roleResources == nil)
    }

    @Test
    func markSurfaceDestroyedRejectsLiveRoleResources() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        try runtime.installRoleResources(RoleToken(rawValue: 1))

        #expect(throws: SurfaceRuntimeError.surfaceDestroyedWithLiveRoleResources) {
            try runtime.markSurfaceDestroyed()
        }
        #expect(runtime.roleResources == RoleToken(rawValue: 1))
    }

    @Test
    func removedRoleResourcesAllowSurfaceDestruction() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        try runtime.installRoleResources(RoleToken(rawValue: 1))
        _ = runtime.removeRoleResources()

        try runtime.markSurfaceDestroyed()

        #expect(runtime.roleResources == nil)
        #expect(runtime.buffers == nil)
    }

    @Test
    func installingRoleResourcesAfterSurfaceDestroyedReturnsError() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        try runtime.markSurfaceDestroyed()

        #expect(throws: SurfaceRuntimeError.installAfterSurfaceDestroyed) {
            try runtime.installRoleResources(RoleToken(rawValue: 1))
        }
        runtime.roleResources = RoleToken(rawValue: 2)

        #expect(runtime.roleResources == nil)
    }

    @Test
    func scaleInstallationUpdateAfterSurfaceDestructionIsIgnored() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
        var didRunUpdate = false

        try runtime.markSurfaceDestroyed()
        runtime.scaleInstallation = SurfaceScaleInstallation()
        _ = runtime.scaleInstallation
        let result = runtime.updateScaleInstallation { _ in
            didRunUpdate = true
            return true
        }

        #expect(result == false)
        #expect(!didRunUpdate)
    }

    @Test
    func roleResourcesCannotBeInstalledTwice() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .popup)

        try runtime.installRoleResources(RoleToken(rawValue: 1))

        #expect(throws: SurfaceRuntimeError.roleResourcesAlreadyInstalled(role: .popup)) {
            try runtime.installRoleResources(RoleToken(rawValue: 2))
        }
        #expect(runtime.roleResources == RoleToken(rawValue: 1))
    }

    @Test
    func roleResourcesCannotBeInstalledAfterRoleRemoval() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .dragIcon)

        try runtime.installRoleResources(RoleToken(rawValue: 1))
        _ = runtime.removeRoleResources()

        #expect(throws: SurfaceRuntimeError.installAfterRoleDestroyed(role: .dragIcon)) {
            try runtime.installRoleResources(RoleToken(rawValue: 2))
        }
    }

    @Test
    func outputMembershipBelongsToSurfaceRuntime() {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        let enteredThirdOutput = runtime.enterOutput(RawOutputID(rawValue: 3))
        let enteredFirstOutput = runtime.enterOutput(RawOutputID(rawValue: 1))
        let duplicateEnter = runtime.enterOutput(RawOutputID(rawValue: 3))

        #expect(enteredThirdOutput)
        #expect(enteredFirstOutput)
        #expect(!duplicateEnter)
        #expect(runtime.currentOutputIDs() == [OutputID(rawValue: 1), OutputID(rawValue: 3)])

        let leftFirstOutput = runtime.leaveOutput(RawOutputID(rawValue: 1))

        #expect(leftFirstOutput)
        #expect(runtime.currentOutputIDs() == [OutputID(rawValue: 3)])

        let removedThirdOutput = runtime.removeOutput(OutputID(rawValue: 3))

        #expect(removedThirdOutput)
        #expect(runtime.currentOutputIDs().isEmpty)
    }

    @Test
    func surfaceDestructionDropsOutputMembershipAndSurfaceCapabilities() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        _ = runtime.enterOutput(RawOutputID(rawValue: 1))
        runtime.setPresentationFeedbackCapability(.available)

        try runtime.markSurfaceDestroyed()

        #expect(runtime.currentOutputIDs().isEmpty)
        #expect(
            runtime.capabilitySnapshot()
                == SurfaceCapabilitySnapshot(
                    role: .toplevelWindow,
                    outputIDs: [],
                    fractionalScale: .integerOnly,
                    presentationFeedback: .unavailable,
                    dmabufFeedback: .unavailable,
                    colorMetadata: .unavailable,
                    explicitSync: .unavailable
                )
        )
    }

    @Test
    func capabilitySnapshotPublishesSurfaceScopedFacts() {
        var runtime = SurfaceRuntime<RoleToken>(role: .popup)

        _ = runtime.enterOutput(RawOutputID(rawValue: 2))
        runtime.setPresentationFeedbackCapability(.available)

        #expect(
            runtime.capabilitySnapshot()
                == SurfaceCapabilitySnapshot(
                    role: .popup,
                    outputIDs: [OutputID(rawValue: 2)],
                    fractionalScale: .integerOnly,
                    presentationFeedback: .available,
                    dmabufFeedback: .unavailable,
                    colorMetadata: .unavailable,
                    explicitSync: .unavailable
                )
        )
    }
}
