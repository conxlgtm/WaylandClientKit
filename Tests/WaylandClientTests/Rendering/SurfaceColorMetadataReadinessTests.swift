#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient
    @testable import WaylandRaw

    @Suite(.serialized)
    struct SurfaceColorMetadataReadinessTests {
        private struct RoleToken: Equatable {}

        @Test
        func colorRepresentationCapabilityIsPendingUntilSupportDone() async throws {
            try await withColorRepresentationManager { manager in
                let globals = OptionalGlobals(colorRepresentationManager: .bound(manager))

                #expect(
                    globals.surfaceColorRepresentationCapability == .pending(version: 1)
                )
            }
        }

        @Test
        func partialColorRepresentationSupportDoesNotBecomeAvailable() async throws {
            try await withColorRepresentationManager { manager in
                #expect(
                    swl_test_color_representation_listener_emit_supported_alpha_mode(
                        RawSurfaceAlphaMode.straight.rawValue
                    ) == 1
                )

                let globals = OptionalGlobals(colorRepresentationManager: .bound(manager))

                #expect(
                    globals.surfaceColorRepresentationCapability == .pending(version: 1)
                )
            }
        }

        @Test
        func colorRepresentationCapabilityPublishesSupportAfterDone() async throws {
            try await withColorRepresentationManager { manager in
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

                let globals = OptionalGlobals(colorRepresentationManager: .bound(manager))

                #expect(
                    globals.surfaceColorRepresentationCapability
                        == .available(
                            version: 1,
                            support: SurfaceColorRepresentationSupport(
                                alphaModes: [.straight],
                                coefficientsAndRanges: [
                                    SurfaceMatrixCoefficientsAndRange(
                                        coefficients: .bt709,
                                        range: .limited
                                    )
                                ]
                            )
                        )
                )
            }
        }

        @Test
        func commitBeforeColorRepresentationSupportDoneDoesNotReportUnsupportedAlphaMode() {
            #expect(throws: SurfaceCommitMetadataError.colorRepresentationSupportPending) {
                try SurfaceCommitMetadata(
                    colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
                ).validate(
                    capabilities: metadataCapabilities(
                        colorRepresentation: .pending(version: 1)
                    ))
            }
        }

        @Test
        func unsupportedAlphaModeRejectedAfterSupportDone() {
            #expect(
                throws: SurfaceCommitMetadataError.unsupportedAlphaMode(.straight)
            ) {
                try SurfaceCommitMetadata(
                    colorRepresentation: SurfaceColorRepresentation(alphaMode: .straight)
                ).validate(
                    capabilities: metadataCapabilities(
                        colorRepresentation: .available(
                            version: 1,
                            support: SurfaceColorRepresentationSupport(
                                alphaModes: [.premultipliedElectrical],
                                coefficientsAndRanges: []
                            )
                        )
                    ))
            }
        }

        @Test
        func pendingImageDescriptionCannotBeCommitted() async throws {
            try await withColorManagerAndSurface { manager, surface in
                var runtime = SurfaceRuntime<RoleToken>(
                    role: .toplevelWindow,
                    surfaceID: surface.objectID
                )
                let reference = try SurfaceColorDescriptionReference(identity: 11)
                runtime.installColorManagementObject(try manager.surface(for: surface))

                try runtime.resolveColorDescriptionIfNeeded(
                    reference,
                    using: manager,
                    surface: surface
                )
                #expect(!runtime.hasColorDescription(reference))

                #expect(
                    throws: SurfaceCommitMetadataError.colorDescriptionPending(reference)
                ) {
                    try runtime.applyCommitMetadata(
                        SurfaceCommitMetadata(colorDescription: reference)
                    )
                }
            }
        }

        @Test
        func readyImageDescriptionCanBeCommitted() async throws {
            try await withColorManagerAndSurface { manager, surface in
                var runtime = SurfaceRuntime<RoleToken>(
                    role: .toplevelWindow,
                    surfaceID: surface.objectID
                )
                let reference = try SurfaceColorDescriptionReference(identity: 11)
                runtime.installColorManagementObject(try manager.surface(for: surface))

                try runtime.resolveColorDescriptionIfNeeded(
                    reference,
                    using: manager,
                    surface: surface
                )
                #expect(
                    swl_test_image_description_listener_emit_ready2(
                        0,
                        UInt32(reference.identity.rawValue)
                    ) == 1
                )
                #expect(runtime.hasColorDescription(reference))

                try runtime.applyCommitMetadata(
                    SurfaceCommitMetadata(colorDescription: reference)
                )

                expectColorDescriptionSetRequest()
            }
        }

        @Test
        func failedImageDescriptionIsRejectedWithCause() async throws {
            try await withColorManagerAndSurface { manager, surface in
                var runtime = SurfaceRuntime<RoleToken>(
                    role: .toplevelWindow,
                    surfaceID: surface.objectID
                )
                let reference = try SurfaceColorDescriptionReference(identity: 12)
                runtime.installColorManagementObject(try manager.surface(for: surface))

                try runtime.resolveColorDescriptionIfNeeded(
                    reference,
                    using: manager,
                    surface: surface
                )
                #expect(
                    unsafe swl_test_image_description_listener_emit_failed(
                        RawImageDescriptionFailureCause.noOutput.rawValue,
                        "gone"
                    ) == 1
                )

                #expect(
                    throws: SurfaceCommitMetadataError.colorDescriptionFailed(
                        reference,
                        cause: .noOutput,
                        message: "gone"
                    )
                ) {
                    try runtime.applyCommitMetadata(
                        SurfaceCommitMetadata(colorDescription: reference)
                    )
                }
            }
        }
    }

    private func metadataCapabilities(
        colorRepresentation: SurfaceColorRepresentationCapability = .unavailable
    ) -> SurfaceCapabilitySnapshot {
        SurfaceCapabilitySnapshot(
            role: .toplevelWindow,
            outputIDs: [],
            fractionalScale: .integerOnly,
            presentationFeedback: .unavailable,
            dmabuf: .unavailable,
            synchronization: .implicitOnly,
            pacing: .unavailable,
            contentType: .unavailable,
            alphaModifier: .unavailable,
            tearingControl: .unavailable,
            colorRepresentation: colorRepresentation,
            color: .unavailable
        )
    }

    private func withColorRepresentationManager(
        _ operation: (RawColorRepresentationManager) throws -> Void
    ) async throws {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                swl_test_metadata_request_recording_begin()
                swl_test_metadata_listener_recording_begin()
                defer { swl_test_metadata_listener_recording_end() }
                defer { swl_test_metadata_request_recording_end() }
                defer { swl_test_core_request_recording_end() }

                let manager = try RawColorRepresentationManager(
                    pointer: try unsafe testMetadataPointer(0xD401),
                    version: 1,
                    proxyAdoption: try metadataTestAdoptionContext()
                )
                defer { manager.destroy() }
                try operation(manager)
            }
        }
    }

    private func withColorManagerAndSurface(
        _ operation: (RawColorManager, RawSurface) throws -> Void
    ) async throws {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                swl_test_metadata_request_recording_begin()
                swl_test_metadata_listener_recording_begin()
                defer { swl_test_metadata_listener_recording_end() }
                defer { swl_test_metadata_request_recording_end() }
                defer { swl_test_core_request_recording_end() }

                let surface = try unsafe RawSurface.testingSurface(
                    pointer: testMetadataPointer(0xD501),
                    version: 6,
                    proxyAdoption: try metadataTestAdoptionContext()
                )
                defer { surface.destroy() }

                let manager = try RawColorManager(
                    pointer: try unsafe testMetadataPointer(0xD502),
                    version: 2,
                    proxyAdoption: try metadataTestAdoptionContext()
                )
                defer { manager.destroy() }

                try operation(manager, surface)
            }
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

    private func expectColorDescriptionSetRequest() {
        let record = unsafe swl_test_metadata_request_record()
        #expect(unsafe record.call_count == 4)
        #expect(
            unsafe record.kind == SWL_TEST_METADATA_COLOR_SURFACE_SET_IMAGE_DESCRIPTION
        )
        #expect(unsafe record.object == UnsafeMutableRawPointer(bitPattern: 0xC706))
        #expect(
            unsafe record.image_description == UnsafeMutableRawPointer(bitPattern: 0xC708)
        )
    }

    private func metadataTestAdoptionContext() throws -> RawProxyAdoptionContext {
        let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
            opaquePointer: try testMetadataPointer(0xD499)
        )
        return RawProxyAdoptionContext(eventQueue: eventQueue)
    }

    private func testMetadataPointer(_ rawPointer: UInt) throws -> OpaquePointer {
        try unsafe #require(OpaquePointer(bitPattern: rawPointer))
    }

#endif
