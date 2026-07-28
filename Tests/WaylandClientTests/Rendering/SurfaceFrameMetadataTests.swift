import Testing

@testable import WaylandClient

@Suite
struct SurfaceFrameMetadataTests {
    @Test
    func defaultRepresentsFullFrameDamageWithNil() {
        let metadata = SurfaceFrameMetadata.default

        #expect(metadata.contentType == nil)
        #expect(metadata.presentationHint == nil)
        #expect(metadata.alpha == nil)
        #expect(metadata.colorRepresentation == nil)
        #expect(metadata.damage == nil)
    }

    @Test
    func rendererNeutralMetadataConvertsWithoutChangingSurfaceValues() throws {
        let damage = try SurfaceDamageRegion([
            LogicalRect(x: 1, y: 2, width: 3, height: 4)
        ])
        let metadata = SurfaceFrameMetadata(
            contentType: .video,
            presentationHint: .async,
            alpha: .transparent,
            colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight),
            damage: damage
        )

        #expect(
            metadata.surfaceCommitMetadata
                == SurfaceCommitMetadata(
                    contentType: .video,
                    alpha: SurfaceAlphaMetadata(multiplier: .transparent),
                    colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight),
                    presentationHint: .async
                )
        )
        #expect(metadata.damage == damage)
    }

    @Test
    func eachExplicitlyUnavailableMetadataDimensionThrowsItsPublicTypedError() {
        let unsupportedRequests: [(SurfaceFrameMetadata, SurfaceFrameMetadataError)] = [
            (
                SurfaceFrameMetadata(contentType: .photo),
                .contentTypeUnavailable
            ),
            (
                SurfaceFrameMetadata(presentationHint: .async),
                .presentationHintUnavailable
            ),
            (
                SurfaceFrameMetadata(alpha: .opaque),
                .alphaMultiplierUnavailable
            ),
            (
                SurfaceFrameMetadata(
                    colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
                ),
                .colorRepresentationUnavailable
            ),
        ]
        let unavailableCapabilities = SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .unavailable
        )

        for (metadata, expectedError) in unsupportedRequests {
            #expect(throws: expectedError) {
                try metadata.validate(capabilities: unavailableCapabilities)
            }
        }
    }
}
