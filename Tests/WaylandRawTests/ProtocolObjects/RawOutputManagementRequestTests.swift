#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawOutputManagementRequestTests {
        @Test
        func outputHeadAndModeDestroySendReleaseRequests() throws {
            try assertHeadReleaseRequest(
                pointer: 0xC701,
                expectedKind: SWL_TEST_OUTPUT_HEAD_RELEASE
            )
            try assertModeReleaseRequest(
                pointer: 0xC702,
                expectedKind: SWL_TEST_OUTPUT_MODE_RELEASE
            )
        }

        private func assertHeadReleaseRequest(
            pointer rawPointer: UInt,
            expectedKind: swl_test_output_destroy_kind,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            RawWlrOutputHead(pointer: pointer).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }

        private func assertModeReleaseRequest(
            pointer rawPointer: UInt,
            expectedKind: swl_test_output_destroy_kind,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            RawWlrOutputMode(pointer: pointer).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }

        @safe
        private func assertReleaseRecord(
            expectedKind: swl_test_output_destroy_kind,
            pointer: OpaquePointer,
            sourceLocation: SourceLocation
        ) {
            let record = unsafe swl_test_output_destroy_record()
            #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
            #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
            #expect(
                unsafe record.object == UnsafeMutableRawPointer(pointer),
                sourceLocation: sourceLocation
            )
        }
    }
#endif
