#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient
    @testable import WaylandRaw

    @Suite(.serialized)
    struct SurfaceRegionApplicatorTests {
        @Test
        func applicatorAddsEveryRectangleBeforeSetAndDestroy() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let surface = try testSurface(pointer: 0xE101)
                defer { surface.destroy() }
                let regionPointer = try unsafe testPointer(0xE102)
                let region = SurfaceRegion([
                    try LogicalRect(x: 1, y: 2, width: 3, height: 4),
                    try LogicalRect(x: 5, y: 6, width: 7, height: 8),
                ])
                var setRegionPointer: OpaquePointer?

                try SurfaceRegionApplicator.apply(
                    region,
                    createRegion: {
                        RawRegion(pointer: regionPointer)
                    }
                ) { rawRegion in
                    unsafe setRegionPointer = rawRegion?.pointer
                    surface.setInputRegion(rawRegion)
                }

                let addRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe addRecord.call_count == 2)
                #expect(unsafe addRecord.kind == SWL_TEST_POINTER_CAPTURE_REGION_ADD)
                #expect(unsafe addRecord.object == UnsafeMutableRawPointer(regionPointer))
                #expect(unsafe addRecord.x == 5)
                #expect(unsafe addRecord.y == 6)
                #expect(unsafe addRecord.width == 7)
                #expect(unsafe addRecord.height == 8)

                let destroyRecord = unsafe swl_test_pointer_capture_destroy_record()
                #expect(unsafe destroyRecord.call_count == 1)
                #expect(
                    unsafe destroyRecord.kind
                        == SWL_TEST_POINTER_CAPTURE_DESTROY_REGION
                )
                #expect(unsafe destroyRecord.object == UnsafeMutableRawPointer(regionPointer))

                surface.commit()

                let coreRecord = unsafe swl_test_core_request_record()
                #expect(unsafe coreRecord.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe coreRecord.object == UnsafeMutableRawPointer(surface.pointer))
                #expect(unsafe coreRecord.region == setRegionPointer)
                #expect(unsafe coreRecord.input_region_sequence > 0)
                #expect(unsafe coreRecord.input_region_sequence < coreRecord.commit_sequence)
            }
        }

        @Test
        func emptySurfaceRegionCreatesRawRegionWithoutRectanglesAndDoesNotResetToNil()
            async throws
        {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let surface = try testSurface(pointer: 0xE301)
                defer { surface.destroy() }
                let regionPointer = try unsafe testPointer(0xE302)
                let region = SurfaceRegion([])
                var setRegionPointer: OpaquePointer?

                try SurfaceRegionApplicator.apply(
                    region,
                    createRegion: {
                        RawRegion(pointer: regionPointer)
                    }
                ) { rawRegion in
                    unsafe setRegionPointer = rawRegion?.pointer
                    surface.setInputRegion(rawRegion)
                }

                let addRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe addRecord.call_count == 0)

                let destroyRecord = unsafe swl_test_pointer_capture_destroy_record()
                #expect(unsafe destroyRecord.call_count == 1)
                #expect(
                    unsafe destroyRecord.kind
                        == SWL_TEST_POINTER_CAPTURE_DESTROY_REGION
                )
                #expect(unsafe destroyRecord.object == UnsafeMutableRawPointer(regionPointer))

                surface.commit()

                let coreRecord = unsafe swl_test_core_request_record()
                #expect(unsafe coreRecord.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe coreRecord.region == setRegionPointer)
                #expect(unsafe coreRecord.region == regionPointer)
                #expect(unsafe coreRecord.region != nil)
                #expect(unsafe coreRecord.input_region_sequence > 0)
                #expect(unsafe coreRecord.input_region_sequence < coreRecord.commit_sequence)
            }
        }

        @Test
        func applicatorNilRegionCommitsNullResetWithoutCreatingRegion() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let surface = try testSurface(pointer: 0xE201)
                defer { surface.destroy() }

                try SurfaceRegionApplicator.apply(
                    nil,
                    createRegion: {
                        Issue.record("nil region must not create a raw region")
                        return RawRegion(pointer: try unsafe testPointer(0xE202))
                    }
                ) { rawRegion in
                    surface.setOpaqueRegion(rawRegion)
                }

                surface.commit()

                let coreRecord = unsafe swl_test_core_request_record()
                #expect(unsafe coreRecord.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe coreRecord.object == UnsafeMutableRawPointer(surface.pointer))
                #expect(unsafe coreRecord.region == nil)
                #expect(unsafe coreRecord.opaque_region_sequence > 0)
                #expect(unsafe coreRecord.opaque_region_sequence < coreRecord.commit_sequence)

                let destroyRecord = unsafe swl_test_pointer_capture_destroy_record()
                #expect(unsafe destroyRecord.call_count == 0)
            }
        }

        private func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
            try unsafe RawSurface.testingSurface(
                pointer: testPointer(rawPointer),
                version: 6,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try testPointer(0xE999)
            )
            return RawProxyAdoptionContext(eventQueue: eventQueue)
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
