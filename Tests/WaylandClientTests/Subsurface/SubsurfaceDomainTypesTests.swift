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

        #expect(
            ClientError.display(.unknownSubsurface(identity)).description.contains(
                identity.description))
        #expect(
            ClientError.display(.foreignSubsurface(identity)).description.contains(
                identity.description))
        #expect(ClientError.display(.closedSubsurface).description.contains("closed"))
    }
}
