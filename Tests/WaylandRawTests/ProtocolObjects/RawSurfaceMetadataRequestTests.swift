import CWaylandProtocols
import Testing

@testable import WaylandRaw

@Suite(.serialized)
struct RawContentTypeMetadataRequestTests {
    @Test
    func managerFactoryRecordsSurfaceAndRejectsDuplicate() async throws {
        try await withCoreAndMetadataRequestRecording {
            let surface = try testSurface(pointer: 0xC201)
            defer { surface.destroy() }
            let manager = try RawContentTypeManager(
                pointer: try unsafe testPointer(0xC202),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
            defer { manager.destroy() }

            let contentType = try manager.contentType(for: surface)
            defer { contentType.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_CONTENT_TYPE_GET_SURFACE,
                callCount: 1,
                object: 0xC202,
                surface: 0xC201
            )

            #expect(
                throws: RuntimeError.invalidArgument(
                    RawSurfaceMetadataError.contentTypeAlreadyExists.description
                )
            ) {
                try manager.contentType(for: surface)
            }
            expectMetadataRequestCallCount(1)
        }
    }

    @Test
    func surfaceSetterRecordsProtocolValue() async throws {
        try await withMetadataRequestRecording {
            let contentType = RawContentTypeSurface(
                pointer: try unsafe testPointer(0xC301),
                destroy: unsafe swl_wp_content_type_v1_destroy
            )
            defer { contentType.destroy() }

            contentType.setContentType(.game)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_CONTENT_TYPE_SET,
                callCount: 1,
                object: 0xC301,
                value: RawContentType.game.rawValue
            )
        }
    }
}

@Suite(.serialized)
struct RawAlphaModifierMetadataRequestTests {
    @Test
    func managerSetterAndDuplicateAreRecorded() async throws {
        try await withAlphaModifierFixture { surface, manager in
            let alphaModifier = try manager.alphaModifier(for: surface)
            defer { alphaModifier.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_ALPHA_MODIFIER_GET_SURFACE,
                callCount: 1,
                object: 0xC352,
                surface: 0xC351
            )

            alphaModifier.setMultiplier(.transparent)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_ALPHA_MODIFIER_SET_MULTIPLIER,
                callCount: 2,
                object: 0xC704,
                value: RawAlphaMultiplier.transparent.rawValue
            )

            #expect(
                throws: RuntimeError.invalidArgument(
                    RawSurfaceMetadataError.alphaModifierAlreadyExists.description
                )
            ) {
                try manager.alphaModifier(for: surface)
            }
            expectMetadataRequestCallCount(2)
        }
    }

    @Test
    func surfaceDestroyAllowsReplacement() async throws {
        try await withAlphaModifierFixture { surface, manager in
            let alphaModifier = try manager.alphaModifier(for: surface)
            alphaModifier.destroy()

            let replacement = try manager.alphaModifier(for: surface)
            defer { replacement.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_ALPHA_MODIFIER_GET_SURFACE,
                callCount: 2,
                object: 0xC352,
                surface: 0xC351
            )
        }
    }
}

@Suite(.serialized)
struct RawTearingControlMetadataRequestTests {
    @Test
    func managerSetterAndDuplicateAreRecorded() async throws {
        try await withTearingControlFixture { surface, manager in
            let tearingControl = try manager.tearingControl(for: surface)
            defer { tearingControl.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_TEARING_CONTROL_GET_SURFACE,
                callCount: 1,
                object: 0xC372,
                surface: 0xC371
            )

            tearingControl.setPresentationHint(.async)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_TEARING_CONTROL_SET_PRESENTATION_HINT,
                callCount: 2,
                object: 0xC705,
                value: RawPresentationHint.async.rawValue
            )

            #expect(
                throws: RuntimeError.invalidArgument(
                    RawSurfaceMetadataError.tearingControlAlreadyExists.description
                )
            ) {
                try manager.tearingControl(for: surface)
            }
            expectMetadataRequestCallCount(2)
        }
    }

    @Test
    func surfaceDestroyAllowsReplacement() async throws {
        try await withTearingControlFixture { surface, manager in
            let tearingControl = try manager.tearingControl(for: surface)
            tearingControl.destroy()

            let replacement = try manager.tearingControl(for: surface)
            defer { replacement.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_TEARING_CONTROL_GET_SURFACE,
                callCount: 2,
                object: 0xC372,
                surface: 0xC371
            )
        }
    }
}

@Suite(.serialized)
struct RawColorRepresentationMetadataRequestTests {
    @Test
    func managerInstallsListenerAndRejectsDuplicateSurface() async throws {
        try await withCoreMetadataRequestAndListenerRecording {
            let surface = try testSurface(pointer: 0xC401)
            defer { surface.destroy() }
            let manager = try RawColorRepresentationManager(
                pointer: try unsafe testPointer(0xC402),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
            defer { manager.destroy() }
            expectMetadataListener(object: 0xC402)

            let colorRepresentation = try manager.colorRepresentation(for: surface)
            defer { colorRepresentation.destroy() }
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_REPRESENTATION_GET_SURFACE,
                callCount: 1,
                object: 0xC402,
                surface: 0xC401
            )

            #expect(
                throws: RuntimeError.invalidArgument(
                    RawSurfaceMetadataError.colorRepresentationAlreadyExists.description
                )
            ) {
                try manager.colorRepresentation(for: surface)
            }
            expectMetadataRequestCallCount(1)
        }
    }

    @Test
    func managerRecordsSupportEventsFromListenerBoundary() async throws {
        try await withCoreMetadataRequestAndListenerRecording {
            let manager = try RawColorRepresentationManager(
                pointer: try unsafe testPointer(0xC432),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
            defer { manager.destroy() }

            #expect(
                swl_test_color_representation_listener_emit_supported_alpha_mode(
                    RawSurfaceAlphaMode.straight.rawValue
                ) == 1
            )
            let emittedCoefficients = emitColorRepresentationCoefficientsAndRange(
                coefficients: .bt709,
                range: .limited
            )
            #expect(emittedCoefficients == 1)
            #expect(swl_test_color_representation_listener_emit_done() == 1)

            #expect(manager.supportedAlphaModes == [.straight])
            #expect(
                manager.supportedCoefficientsAndRanges == [
                    RawSurfaceCoefficientsAndRange(
                        coefficients: .bt709,
                        range: .limited
                    )
                ]
            )
            #expect(manager.hasReceivedSupportDone)
        }
    }

    @Test
    func settersRecordProtocolValues() async throws {
        try await withMetadataRequestRecording {
            let surface = RawColorRepresentationSurface(
                pointer: try unsafe testPointer(0xC501),
                destroy: unsafe swl_wp_color_representation_surface_v1_destroy
            )
            defer { surface.destroy() }

            surface.setAlphaMode(.straight)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_ALPHA_MODE,
                callCount: 1,
                object: 0xC501,
                value: RawSurfaceAlphaMode.straight.rawValue
            )

            surface.setCoefficientsAndRange(
                RawSurfaceCoefficientsAndRange(coefficients: .bt709, range: .limited)
            )
            expectMetadataRequest(
                kind:
                    SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_COEFFICIENTS_AND_RANGE,
                callCount: 2,
                object: 0xC501,
                coefficients: RawSurfaceMatrixCoefficients.bt709.rawValue,
                range: RawSurfaceQuantizationRange.limited.rawValue
            )

            surface.setChromaLocation(.type3)
            expectMetadataRequest(
                kind: SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_CHROMA_LOCATION,
                callCount: 3,
                object: 0xC501,
                value: RawSurfaceChromaLocation.type3.rawValue
            )
        }
    }
}

private func withAlphaModifierFixture(
    _ operation: (RawSurface, RawAlphaModifierManager) throws -> Void
) async throws {
    try await withCoreAndMetadataRequestRecording {
        let surface = try testSurface(pointer: 0xC351)
        defer { surface.destroy() }
        let manager = try RawAlphaModifierManager(
            pointer: try unsafe testPointer(0xC352),
            version: 1,
            proxyAdoption: try testAdoptionContext()
        )
        defer { manager.destroy() }
        try operation(surface, manager)
    }
}

private func withTearingControlFixture(
    _ operation: (RawSurface, RawTearingControlManager) throws -> Void
) async throws {
    try await withCoreAndMetadataRequestRecording {
        let surface = try testSurface(pointer: 0xC371)
        defer { surface.destroy() }
        let manager = try RawTearingControlManager(
            pointer: try unsafe testPointer(0xC372),
            version: 1,
            proxyAdoption: try testAdoptionContext()
        )
        defer { manager.destroy() }
        try operation(surface, manager)
    }
}

private func emitColorRepresentationCoefficientsAndRange(
    coefficients: RawSurfaceMatrixCoefficients,
    range: RawSurfaceQuantizationRange
) -> Int32 {
    swl_test_color_representation_listener_emit_supported_coefficients_and_ranges(
        coefficients.rawValue,
        range.rawValue
    )
}
