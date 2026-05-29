#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawSurfaceRegionRequestTests {
        @Test
        func setOpaqueRegionPreservesSurfaceAndRegionPointers() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let surface = try testSurface(pointer: 0xD101)
                defer { surface.destroy() }
                let region = try testRegion(pointer: 0xD102)
                defer { region.destroy() }

                surface.setOpaqueRegion(region)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_SET_OPAQUE_REGION)
                #expect(unsafe record.object == UnsafeMutableRawPointer(surface.pointer))
                #expect(unsafe record.region == region.pointer)
                #expect(unsafe record.opaque_region_sequence > 0)
            }
        }

        @Test
        func regionSubtractPreservesRectangleCoordinates() throws {
            try ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let region = try testRegion(pointer: 0xD301)
                defer { region.destroy() }

                region.subtract(x: 1, y: 2, width: 3, height: 4)

                let record = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_REGION_SUBTRACT)
                #expect(unsafe record.object == UnsafeMutableRawPointer(region.pointer))
                #expect(unsafe record.x == 1)
                #expect(unsafe record.y == 2)
                #expect(unsafe record.width == 3)
                #expect(unsafe record.height == 4)
            }
        }

        @Test
        func setInputRegionNilResetsSurfaceInputRegion() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0xD201)
                defer { surface.destroy() }

                surface.setInputRegion(nil)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_SET_INPUT_REGION)
                #expect(unsafe record.object == UnsafeMutableRawPointer(surface.pointer))
                #expect(unsafe record.region == nil)
                #expect(unsafe record.input_region_sequence > 0)
            }
        }

        private func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
            try unsafe RawSurface.testingSurface(
                pointer: testPointer(rawPointer),
                version: 6,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testRegion(pointer rawPointer: UInt) throws -> RawRegion {
            try unsafe RawRegion(pointer: testPointer(rawPointer))
        }

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try testPointer(0xD999)
            )
            return RawProxyAdoptionContext(eventQueue: eventQueue)
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
