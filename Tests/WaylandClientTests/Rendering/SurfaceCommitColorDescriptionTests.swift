#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite(.serialized)
    struct SurfaceCommitColorDescriptionTests {
        @Test
        func pendingImageDescriptionCannotBeCommitted() async throws {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_metadata_request_recording_begin()
                defer { swl_test_metadata_request_recording_end() }

                var objects = SurfaceMetadataObjects()
                let reference = try SurfaceColorDescriptionReference(identity: 12)
                objects.installColorManagement(try testColorManagementSurface(pointer: 0xD402))
                objects.installColorDescription(
                    try testImageDescription(pointer: 0xD403, state: .pending),
                    reference: reference
                )

                #expect(
                    throws: SurfaceCommitMetadataError.colorDescriptionPending(reference)
                ) {
                    try objects.apply(SurfaceCommitMetadata(colorDescription: reference))
                }
                #expect(unsafe swl_test_metadata_request_record().call_count == 0)
            }
        }

        @Test
        func failedImageDescriptionIsRejectedWithCause() async throws {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_metadata_request_recording_begin()
                defer { swl_test_metadata_request_recording_end() }

                var objects = SurfaceMetadataObjects()
                let reference = try SurfaceColorDescriptionReference(identity: 13)
                objects.installColorManagement(try testColorManagementSurface(pointer: 0xD502))
                objects.installColorDescription(
                    try testImageDescription(
                        pointer: 0xD503,
                        state: .failed(cause: .unsupported, message: "bad image")
                    ),
                    reference: reference
                )

                #expect(
                    throws: SurfaceCommitMetadataError.colorDescriptionFailed(
                        reference,
                        cause: .unsupported,
                        message: "bad image"
                    )
                ) {
                    try objects.apply(SurfaceCommitMetadata(colorDescription: reference))
                }
                #expect(unsafe swl_test_metadata_request_record().call_count == 0)
            }
        }

        @Test
        func readyImageDescriptionIdentityMustMatchRequestedReference() async throws {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_metadata_request_recording_begin()
                defer { swl_test_metadata_request_recording_end() }

                var objects = SurfaceMetadataObjects()
                let reference = try SurfaceColorDescriptionReference(identity: 14)
                objects.installColorManagement(try testColorManagementSurface(pointer: 0xD602))
                objects.installColorDescription(
                    try testImageDescription(
                        pointer: 0xD603,
                        state: .ready(identity: try RawImageDescriptionIdentity(15))
                    ),
                    reference: reference
                )

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

        @Test
        func surfaceImageDescriptionIdentityRejectsZero() {
            #expect(throws: SurfaceCommitMetadataError.invalidColorDescriptionIdentity(0)) {
                _ = try SurfaceImageDescriptionIdentity(0)
            }
        }

        @Test
        func zeroColorDescriptionReferenceCannotReachMetadataApply() async throws {
            try await MetadataRequestRecordingGate.withExclusiveRecording {
                swl_test_metadata_request_recording_begin()
                defer { swl_test_metadata_request_recording_end() }

                #expect(throws: SurfaceCommitMetadataError.invalidColorDescriptionIdentity(0)) {
                    _ = try SurfaceColorDescriptionReference(identity: 0)
                }
                #expect(unsafe swl_test_metadata_request_record().call_count == 0)
            }
        }
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
    ) throws -> RawImageDescription {
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

#endif
