import Testing

@testable import WaylandClient

@Suite
struct SubsurfaceDomainTypesTests {
    @Test
    func subsurfaceIdentityDescriptionUsesDomainPrefix() {
        let identity = SubsurfaceIdentity(SubsurfaceID(rawValue: 7))

        #expect(identity.description == "subsurface-7")
    }

    @Test
    func subsurfaceConfigurationDefaultsArePlatformPrimitiveDefaults() {
        let configuration = SubsurfaceConfiguration()

        #expect(configuration.position == LogicalOffset(x: 0, y: 0))
        #expect(configuration.size == .default)
        #expect(configuration.bufferCount == SubsurfaceConfiguration.defaultBufferCount)
        #expect(configuration.synchronizationMode == .synchronized)
    }

    @Test
    func subsurfaceDisplayErrorsAreMachineMatchable() {
        let identity = SubsurfaceIdentity(SubsurfaceID(rawValue: 3))
        let sibling = SubsurfaceIdentity(SubsurfaceID(rawValue: 4))

        #expect(
            ClientError.display(.unknownSubsurface(identity)).description.contains(
                identity.description))
        #expect(
            ClientError.display(.foreignSubsurface(identity)).description.contains(
                identity.description))
        #expect(ClientError.display(.closedSubsurface).description.contains("closed"))
        #expect(
            ClientError.display(
                .invalidSubsurfaceStacking(.selfReference(identity))
            ).description.contains("itself"))
        #expect(
            ClientError.display(
                .invalidSubsurfaceStacking(
                    .differentParent(subsurface: identity, sibling: sibling)
                )
            ).description.contains(sibling.description))
        #expect(
            ClientError.display(
                .subsurfacePresentationFailed(
                    SubsurfacePresentationFailure(subsurfaceID: identity, reason: "buffer busy")
                )
            ).description.contains("buffer busy"))
    }

    @Test
    func parentCommitRequirementRecordsExplicitProtocolBoundary() {
        let windowID = WindowID(rawValue: 10)
        let subsurfaceID = SubsurfaceID(rawValue: 11)

        let requirement = SubsurfaceParentCommitRequirement(
            parentWindowID: windowID,
            subsurfaceID: subsurfaceID,
            reason: .positionChanged
        )

        #expect(requirement.parentWindowID == windowID)
        #expect(requirement.subsurfaceID == subsurfaceID)
        #expect(requirement.reason == .positionChanged)
    }
}
