#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawOutputManagementRequestTests {
        @Test
        func outputManagerDestroySendsStopWithoutLocalDestroy() throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xC700))

            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            let manager = RawWlrOutputManager.testingOutputManager(
                pointer: pointer,
                version: RawVersion(4),
                proxyAdoption: try testAdoptionContext()
            )

            manager.destroy()
            manager.destroy()

            #expect(throws: RuntimeError.invalidArgument("zwlr_output_manager_v1 stopped")) {
                try manager.createConfiguration(serial: 1)
            }
            assertReleaseRecord(
                expectedKind: SWL_TEST_OUTPUT_MANAGER_STOP,
                pointer: pointer
            )
        }

        @Test
        func outputHeadAndModeDestroySendReleaseRequests() throws {
            try assertHeadReleaseRequest(
                pointer: 0xC701,
                version: RawVersion(3),
                expectedKind: SWL_TEST_OUTPUT_HEAD_RELEASE
            )
            try assertModeReleaseRequest(
                pointer: 0xC702,
                version: RawVersion(3),
                expectedKind: SWL_TEST_OUTPUT_MODE_RELEASE
            )
        }

        @Test
        func outputHeadAndModeBeforeVersion3UseLocalDestroy() throws {
            try assertHeadReleaseRequest(
                pointer: 0xC703,
                version: RawVersion(2),
                expectedKind: SWL_TEST_OUTPUT_HEAD_DESTROY
            )
            try assertModeReleaseRequest(
                pointer: 0xC704,
                version: RawVersion(2),
                expectedKind: SWL_TEST_OUTPUT_MODE_DESTROY
            )
        }

        private func assertHeadReleaseRequest(
            pointer rawPointer: UInt,
            version: RawVersion,
            expectedKind: swl_test_output_destroy_kind,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            RawWlrOutputHead(pointer: pointer, version: version).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }

        private func assertModeReleaseRequest(
            pointer rawPointer: UInt,
            version: RawVersion,
            expectedKind: swl_test_output_destroy_kind,
            sourceLocation: SourceLocation = #_sourceLocation
        ) throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))

            swl_test_output_request_recording_begin()
            defer { swl_test_output_request_recording_end() }
            RawWlrOutputMode(pointer: pointer, version: version).destroy()

            assertReleaseRecord(
                expectedKind: expectedKind,
                pointer: pointer,
                sourceLocation: sourceLocation
            )
        }

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try #require(OpaquePointer(bitPattern: 0xC799))
            )
            return RawProxyAdoptionContext(eventQueue: eventQueue)
        }

        @safe
        private func assertReleaseRecord(
            expectedKind: swl_test_output_destroy_kind,
            pointer: OpaquePointer,
            sourceLocation: SourceLocation = #_sourceLocation
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
