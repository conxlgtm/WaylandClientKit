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

    @Test(arguments: [
        SurfaceRuntimeRole.toplevelWindow,
        .popup,
        .cursor,
        .dragIcon,
    ])
    func everyRoleRemovesResourcesBeforeSurfaceDestruction(
        role: SurfaceRuntimeRole
    ) throws {
        var runtime = SurfaceRuntime<RoleToken>(role: role)

        try runtime.installRoleResources(RoleToken(rawValue: 1))

        #expect(runtime.removeRoleResources() == RoleToken(rawValue: 1))
        try runtime.markSurfaceDestroyed()
        #expect(runtime.roleResources == nil)
        #expect(runtime.capabilitySnapshot().role == role)
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
                    dmabuf: .unavailable,
                    synchronization: .implicitOnly,
                    pacing: .unavailable
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
                    dmabuf: .unavailable,
                    synchronization: .implicitOnly,
                    pacing: .unavailable
                )
        )
    }

    @Test
    func capabilitySnapshotPublishesSurfaceDmabufFacts() {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        runtime.setDmabufAdvertisement(
            .advertised(version: 5, canRequestSurfaceFeedback: .available)
        )
        #expect(
            runtime.capabilitySnapshot().dmabuf
                == .advertised(version: 5, canRequestSurfaceFeedback: .available)
        )
    }

    @Test
    func surfaceFeedbackRejectsDefaultFeedback() throws {
        let feedback = try feedbackSnapshot(scope: .defaultFeedback)

        #expect(throws: SurfaceDmabufCapabilityError.defaultFeedbackForSurface) {
            _ = try SurfaceDmabufFeedback(
                snapshot: feedback,
                surfaceID: RawObjectID(42)
            )
        }
    }

    @Test
    func surfaceFeedbackRejectsMismatchedSurfaceID() throws {
        let feedback = try feedbackSnapshot(scope: .surface(surfaceID: RawObjectID(42)))

        #expect(
            throws: SurfaceDmabufCapabilityError.mismatchedSurfaceFeedback(
                expected: RawObjectID(7),
                actual: RawObjectID(42)
            )
        ) {
            _ = try SurfaceDmabufFeedback(
                snapshot: feedback,
                surfaceID: RawObjectID(7)
            )
        }
    }

    @Test
    func runtimeStoresOnlySurfaceMatchedDmabufFeedback() throws {
        var runtime = SurfaceRuntime<RoleToken>(
            role: .toplevelWindow,
            surfaceID: RawObjectID(42)
        )
        let feedback = try feedbackSnapshot(scope: .surface(surfaceID: RawObjectID(42)))
        let surfaceFeedback = try SurfaceDmabufFeedback(
            snapshot: feedback,
            surfaceID: RawObjectID(42)
        )

        runtime.setDmabufAdvertisement(
            .advertised(version: 6, canRequestSurfaceFeedback: .available)
        )
        try runtime.setSurfaceDmabufFeedback(feedback)

        #expect(
            runtime.capabilitySnapshot().dmabuf
                == .surfaceFeedback(
                    version: 6,
                    feedback: surfaceFeedback
                )
        )
    }

    @Test
    func runtimeWithoutSurfaceIdentityRejectsDmabufFeedback() throws {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
        let feedback = try feedbackSnapshot(scope: .surface(surfaceID: RawObjectID(42)))

        #expect(throws: SurfaceDmabufCapabilityError.missingSurfaceIdentity) {
            try runtime.setSurfaceDmabufFeedback(feedback)
        }
    }

    private func feedbackSnapshot(
        scope: RawLinuxDmabufFeedbackScope
    ) throws -> RawLinuxDmabufFeedbackSnapshot {
        let formatModifier = RawLinuxDmabufFormatModifier(
            format: 875_713_112,
            modifier: 0
        )
        var state = RawLinuxDmabufFeedbackState()

        state.replaceFormatTable([formatModifier])
        try state.setMainDevice(bytes: [1, 2, 3, 4, 5, 6, 7, 8], scope: scope)
        try state.setCurrentTrancheTargetDevice(
            bytes: [1, 2, 3, 4, 5, 6, 7, 8],
            scope: scope
        )
        try state.setCurrentTrancheFlags(
            RawLinuxDmabufTrancheFlags.scanout.rawValue,
            scope: scope
        )
        try state.appendCurrentTrancheFormats(indices: [0], scope: scope)
        try state.finishCurrentTranche(scope: scope)
        return try state.finish(scope: scope)
    }
}
