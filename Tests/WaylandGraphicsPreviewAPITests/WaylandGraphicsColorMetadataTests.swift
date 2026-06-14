import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsColorMetadataTests {
    @Test
    func colorMetadataFallsBackWhenProtocolsAreUnavailable() throws {
        let metadata = WaylandGraphicsFrameMetadata(
            alpha: .transparent,
            colorRepresentation: WaylandGraphicsColorRepresentation(alphaMode: .straight),
            colorDescription: WaylandGraphicsColorDescription(
                id: try WaylandGraphicsColorDescriptionID(rawValue: 42)
            )
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
        let metadata = WaylandGraphicsFrameMetadata(
            alpha: .opaque,
            colorRepresentation: WaylandGraphicsColorRepresentation(
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
    func zeroColorDescriptionIDIsRejected() {
        #expect(throws: WaylandGraphicsError.unavailable(.invalidColorDescription)) {
            _ = try WaylandGraphicsColorDescriptionID(rawValue: 0)
        }
    }
}
