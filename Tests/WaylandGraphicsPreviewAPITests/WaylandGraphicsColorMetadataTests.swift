import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsColorMetadataTests {
    @Test
    func colorMetadataFallsBackWhenProtocolsAreUnavailable() throws {
        let metadata = SurfaceFrameMetadata(
            colorDescription: try SurfaceColorDescriptionReference(identity: 42),
            alpha: .transparent,
            colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
        )

        let resolved = try metadata.resolveManagedPreviewMetadata(
            configuration: WaylandGraphicsConfiguration(metadataPolicy: .preferAvailable),
            capabilities: softwareOnlySurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )
        let path = resolved.fallbacks.applying(
            to: .projected(capabilities: softwareOnlySurfaceCapabilities())
        )

        #expect(resolved.commitMetadata == .default)
        #expect(path.metadata.alphaModifier == .fallback(.alphaModifierUnavailable))
        #expect(
            path.metadata.colorRepresentation
                == .fallback(.colorRepresentationUnavailable)
        )
        #expect(path.metadata.colorManagement == .fallback(.colorManagementUnavailable))
    }

    @Test
    func colorMetadataMapsWhenProtocolsAreAvailable() throws {
        let metadata = SurfaceFrameMetadata(
            alpha: .opaque,
            colorRepresentation: SurfaceColorRepresentation(
                alphaMode: .premultipliedElectrical
            )
        )

        let resolved = try metadata.resolveManagedPreviewMetadata(
            configuration: WaylandGraphicsConfiguration(metadataPolicy: .preferAvailable),
            capabilities: gpuCapableSurfaceCapabilities(),
            geometry: testGraphicsSurfaceGeometry()
        )

        #expect(resolved.commitMetadata.alpha != nil)
        #expect(resolved.commitMetadata.colorRepresentation != nil)
        #expect(resolved.fallbacks.isEmpty)
    }

    @Test
    func zeroSurfaceColorDescriptionIDIsRejected() {
        #expect(throws: SurfaceCommitMetadataError.invalidColorDescriptionIdentity(0)) {
            _ = try SurfaceColorDescriptionReference(identity: 0)
        }
    }
}
