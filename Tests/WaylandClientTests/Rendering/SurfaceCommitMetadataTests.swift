import CWaylandProtocols
import Testing
import WaylandTestSupport

@testable import WaylandClient
@testable import WaylandRaw

@Suite(.serialized)
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
                colorRepresentation: supportedColorRepresentationCapability(),
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
        runtime.setColorRepresentationCapability(supportedColorRepresentationCapability())
        runtime.setColorCapability(.available(version: 3))

        let snapshot = runtime.capabilitySnapshot()

        #expect(snapshot.contentType == .available)
        #expect(snapshot.alphaModifier == .available)
        #expect(snapshot.tearingControl == .available)
        #expect(snapshot.colorRepresentation == supportedColorRepresentationCapability())
        #expect(snapshot.color == .available(version: 3))
    }

    @Test
    func unsupportedAlphaModeIsRejectedBeforeWaylandRequest() {
        #expect(
            throws: SurfaceCommitMetadataError.unsupportedAlphaMode(
                SurfaceAlphaMode(rawValue: 88)
            )
        ) {
            try SurfaceCommitMetadata(
                colorRepresentation: SurfaceColorRepresentation(
                    alphaMode: SurfaceAlphaMode(rawValue: 88)
                )
            ).validate(
                capabilities: metadataCapabilities(
                    colorRepresentation: supportedColorRepresentationCapability()
                ))
        }
    }

    @Test
    func unsupportedCoefficientsAndRangeIsRejectedBeforeWaylandRequest() {
        let unsupported = SurfaceMatrixCoefficientsAndRange(
            coefficients: SurfaceMatrixCoefficients(rawValue: 77),
            range: .full
        )

        #expect(
            throws: SurfaceCommitMetadataError.unsupportedCoefficientsAndRange(
                unsupported
            )
        ) {
            try SurfaceCommitMetadata(
                colorRepresentation: SurfaceColorRepresentation(
                    coefficientsAndRange: unsupported
                )
            ).validate(
                capabilities: metadataCapabilities(
                    colorRepresentation: supportedColorRepresentationCapability()
                ))
        }
    }

    @Test
    func unknownAdvertisedColorValueIsPreservedButRequiresAdvertisement() throws {
        let advertisedAlphaMode = SurfaceAlphaMode(rawValue: 88)
        let advertisedCoefficientsAndRange = SurfaceMatrixCoefficientsAndRange(
            coefficients: SurfaceMatrixCoefficients(rawValue: 77),
            range: SurfaceQuantizationRange(rawValue: 66)
        )
        let metadata = SurfaceCommitMetadata(
            colorRepresentation: SurfaceColorRepresentation(
                alphaMode: advertisedAlphaMode,
                coefficientsAndRange: advertisedCoefficientsAndRange
            )
        )

        try metadata.validate(
            capabilities: metadataCapabilities(
                colorRepresentation: .available(
                    version: 1,
                    support: SurfaceColorRepresentationSupport(
                        alphaModes: [advertisedAlphaMode],
                        coefficientsAndRanges: [advertisedCoefficientsAndRange]
                    )
                )
            ))
    }

    @Test
    func invalidContentTypeRawValueCannotBeCommitted() {
        let unsupported = SurfaceContentType(rawValue: 99)

        #expect(throws: SurfaceCommitMetadataError.unsupportedContentType(unsupported)) {
            try SurfaceCommitMetadata(contentType: unsupported).validate(
                capabilities: metadataCapabilities(contentType: .available)
            )
        }
    }

    @Test
    func missingColorDescriptionFailsBeforeAnyMetadataRequest() async throws {
        try await MetadataRequestRecordingGate.withExclusiveRecording {
            swl_test_metadata_request_recording_begin()
            defer { swl_test_metadata_request_recording_end() }

            var objects = SurfaceMetadataObjects()
            let missingReference = SurfaceColorDescriptionReference(identity: 7)
            objects.installContentType(try testContentTypeSurface(pointer: 0xD001))
            objects.installColorManagement(try testColorManagementSurface(pointer: 0xD002))

            #expect(
                throws: SurfaceCommitMetadataError.colorDescriptionUnavailable(
                    missingReference
                )
            ) {
                try objects.apply(
                    SurfaceCommitMetadata(
                        contentType: .game,
                        colorDescription: missingReference
                    ))
            }
            #expect(unsafe swl_test_metadata_request_record().call_count == 0)
        }
    }

    @Test
    func metadataApplySendsAllRequestsOnlyAfterPreflightSucceeds() async throws {
        try await MetadataRequestRecordingGate.withExclusiveRecording {
            swl_test_metadata_request_recording_begin()
            defer { swl_test_metadata_request_recording_end() }

            var objects = SurfaceMetadataObjects()
            let reference = SurfaceColorDescriptionReference(identity: 8)
            objects.installContentType(try testContentTypeSurface(pointer: 0xD101))
            objects.installColorManagement(try testColorManagementSurface(pointer: 0xD102))
            objects.installColorDescription(
                try testImageDescription(
                    pointer: 0xD103,
                    state: .ready(identity: reference.identity)
                ),
                reference: reference
            )

            try objects.apply(
                SurfaceCommitMetadata(
                    contentType: .game,
                    colorDescription: reference
                ))

            let record = unsafe swl_test_metadata_request_record()
            #expect(unsafe record.call_count == 2)
            #expect(
                unsafe record.kind
                    == SWL_TEST_METADATA_COLOR_SURFACE_SET_IMAGE_DESCRIPTION
            )
            #expect(unsafe record.object == UnsafeMutableRawPointer(bitPattern: 0xD102))
            #expect(
                unsafe record.image_description
                    == UnsafeMutableRawPointer(bitPattern: 0xD103)
            )
            #expect(unsafe record.render_intent == RawColorRenderIntent.perceptual.rawValue)
        }
    }

    @Test
    func failedMetadataCommitDoesNotDirtyNextCommit() async throws {
        try await MetadataRequestRecordingGate.withExclusiveRecording {
            swl_test_metadata_request_recording_begin()
            defer { swl_test_metadata_request_recording_end() }

            var objects = SurfaceMetadataObjects()
            objects.installContentType(try testContentTypeSurface(pointer: 0xD201))
            objects.installColorManagement(try testColorManagementSurface(pointer: 0xD202))

            #expect(
                throws: SurfaceCommitMetadataError.colorDescriptionUnavailable(
                    SurfaceColorDescriptionReference(identity: 9)
                )
            ) {
                try objects.apply(
                    SurfaceCommitMetadata(
                        contentType: .game,
                        colorDescription: SurfaceColorDescriptionReference(identity: 9)
                    ))
            }

            try objects.apply(.default)
            #expect(unsafe swl_test_metadata_request_record().call_count == 0)
        }
    }

    @Test
    func colorDescriptionMetadataRequiresInstalledReadyDescription() async throws {
        try await MetadataRequestRecordingGate.withExclusiveRecording {
            swl_test_metadata_request_recording_begin()
            defer { swl_test_metadata_request_recording_end() }

            var objects = SurfaceMetadataObjects()
            let reference = SurfaceColorDescriptionReference(identity: 10)
            objects.installColorManagement(try testColorManagementSurface(pointer: 0xD302))

            #expect(
                throws: SurfaceCommitMetadataError.colorDescriptionUnavailable(
                    reference
                )
            ) {
                try objects.apply(SurfaceCommitMetadata(colorDescription: reference))
            }
            #expect(unsafe swl_test_metadata_request_record().call_count == 0)
        }
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

private func supportedColorRepresentationCapability()
    -> SurfaceColorRepresentationCapability
{
    .available(
        version: 2,
        support: SurfaceColorRepresentationSupport(
            alphaModes: [
                .premultipliedElectrical,
                .premultipliedOptical,
                .straight,
            ],
            coefficientsAndRanges: [
                SurfaceMatrixCoefficientsAndRange(
                    coefficients: .bt709,
                    range: .limited
                )
            ]
        )
    )
}

private func testContentTypeSurface(pointer rawPointer: UInt) throws
    -> RawContentTypeSurface
{
    try unsafe RawContentTypeSurface(
        pointer: testMetadataPointer(rawPointer),
        destroy: ignoreTestMetadataDestroy
    )
}

private func testColorManagementSurface(pointer rawPointer: UInt) throws
    -> RawColorManagementSurface
{
    try unsafe RawColorManagementSurface(
        pointer: testMetadataPointer(rawPointer),
        destroy: ignoreTestMetadataDestroy
    )
}

private func testImageDescription(
    pointer rawPointer: UInt,
    state initialState: RawImageDescriptionState
) throws
    -> RawImageDescription
{
    try unsafe RawImageDescription(
        pointer: testMetadataPointer(rawPointer),
        destroy: ignoreTestMetadataDestroy,
        state: initialState
    )
}

private func testMetadataPointer(_ rawPointer: UInt) throws -> OpaquePointer {
    try unsafe #require(OpaquePointer(bitPattern: rawPointer))
}

private func ignoreTestMetadataDestroy(_: OpaquePointer) {
    // Test-owned fake proxies do not need protocol destruction.
}
