import Testing

@testable import WaylandClient

@Suite
struct SurfaceCommitMetadataTests {
    private struct RoleToken: Equatable {}

    @Test
    func defaultMetadataValidatesWithoutOptionalProtocols() throws {
        try SurfaceCommitMetadata.default.validate(capabilities: metadataCapabilities())
    }

    @Test
    func metadataRejectsUnavailableCapabilities() {
        #expect(throws: SurfaceCommitMetadataError.contentTypeUnavailable) {
            try SurfaceCommitMetadata(contentType: .video)
                .validate(capabilities: metadataCapabilities())
        }
        #expect(throws: SurfaceCommitMetadataError.alphaModifierUnavailable) {
            try SurfaceCommitMetadata(
                alpha: SurfaceAlphaMetadata(multiplier: .transparent)
            ).validate(capabilities: metadataCapabilities())
        }
        #expect(throws: SurfaceCommitMetadataError.tearingControlUnavailable) {
            try SurfaceCommitMetadata(presentationHint: .async)
                .validate(capabilities: metadataCapabilities())
        }
        #expect(throws: SurfaceCommitMetadataError.colorRepresentationUnavailable) {
            try SurfaceCommitMetadata(
                colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
            ).validate(capabilities: metadataCapabilities())
        }
        #expect(throws: SurfaceCommitMetadataError.colorUnavailable) {
            try SurfaceCommitMetadata(
                colorDescription: SurfaceColorDescriptionReference(identity: 7)
            ).validate(capabilities: metadataCapabilities())
        }
    }

    @Test
    func metadataValidatesWithAvailableCapabilities() throws {
        let metadata = SurfaceCommitMetadata(
            contentType: .game,
            alpha: SurfaceAlphaMetadata(multiplier: .opaque),
            colorRepresentation: SurfaceColorRepresentation(
                alphaMode: .premultipliedElectrical,
                coefficientsAndRange: SurfaceMatrixCoefficientsAndRange(
                    coefficients: .bt709,
                    range: .limited
                ),
                chromaLocation: .type1
            ),
            colorDescription: SurfaceColorDescriptionReference(identity: 9),
            presentationHint: .async
        )

        try metadata.validate(
            capabilities: metadataCapabilities(
                contentType: .available,
                alphaModifier: .available,
                tearingControl: .available,
                colorRepresentation: .available(version: 1),
                color: .available(version: 1)
            )
        )
    }

    @Test
    func surfaceRuntimePublishesMetadataCapabilities() {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

        runtime.setContentTypeCapability(.available)
        runtime.setAlphaModifierCapability(.available)
        runtime.setTearingControlCapability(.available)
        runtime.setColorRepresentationCapability(.available(version: 2))
        runtime.setColorCapability(.available(version: 3))

        let snapshot = runtime.capabilitySnapshot()

        #expect(snapshot.contentType == .available)
        #expect(snapshot.alphaModifier == .available)
        #expect(snapshot.tearingControl == .available)
        #expect(snapshot.colorRepresentation == .available(version: 2))
        #expect(snapshot.color == .available(version: 3))
    }

    @Test
    func metadataValuesPreserveUnknownRawValues() {
        #expect(SurfaceContentType(rawValue: 99).rawValue == 99)
        #expect(SurfaceAlphaMultiplier(rawValue: 123).rawValue == 123)
        #expect(SurfaceAlphaMode(rawValue: 88).rawValue == 88)
        #expect(SurfaceMatrixCoefficients(rawValue: 77).rawValue == 77)
        #expect(SurfaceQuantizationRange(rawValue: 66).rawValue == 66)
        #expect(SurfaceChromaLocation(rawValue: 55).rawValue == 55)
    }
}

private func metadataCapabilities(
    contentType: SurfaceCapabilityStatus = .unavailable,
    alphaModifier: SurfaceCapabilityStatus = .unavailable,
    tearingControl: SurfaceCapabilityStatus = .unavailable,
    colorRepresentation: SurfaceColorRepresentationCapability = .unavailable,
    color: SurfaceColorCapability = .unavailable
) -> SurfaceCapabilitySnapshot {
    SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .unavailable,
        dmabuf: .unavailable,
        synchronization: .implicitOnly,
        pacing: .unavailable,
        contentType: contentType,
        alphaModifier: alphaModifier,
        tearingControl: tearingControl,
        colorRepresentation: colorRepresentation,
        color: color
    )
}
