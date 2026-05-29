#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawSubsurfaceRequestTests {
        @Test
        func getSubsurfacePreservesChildAndParentPointers() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subcompositor = try testSubcompositor(pointer: 0xE101)
                defer { subcompositor.destroy() }
                let child = try testSurface(pointer: 0xE102)
                defer { child.destroy() }
                let parent = try testSurface(pointer: 0xE103)
                defer { parent.destroy() }

                let subsurface = try subcompositor.getSubsurface(
                    surface: child,
                    parent: parent
                )
                defer { subsurface.destroy() }

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(
                    unsafe record.kind
                        == SWL_TEST_CORE_SUBCOMPOSITOR_GET_SUBSURFACE
                )
                #expect(unsafe record.object == UnsafeMutableRawPointer(subcompositor.pointer))
                #expect(unsafe record.surface == child.pointer)
                #expect(unsafe record.parent == parent.pointer)
                #expect(unsafe record.subsurface == subsurface.pointer)
            }
        }

        @Test
        func subsurfaceSetPositionPreservesCoordinates() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subsurface = try testSubsurface(pointer: 0xE201)
                defer { subsurface.destroy() }

                subsurface.setPosition(x: 12, y: -4)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SUBSURFACE_SET_POSITION)
                #expect(unsafe record.object == UnsafeMutableRawPointer(subsurface.pointer))
                #expect(unsafe record.x == 12)
                #expect(unsafe record.y == -4)
            }
        }

        @Test
        func subsurfacePlaceAbovePreservesSiblingPointer() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subsurface = try testSubsurface(pointer: 0xE301)
                defer { subsurface.destroy() }
                let sibling = try testSurface(pointer: 0xE302)
                defer { sibling.destroy() }

                subsurface.placeAbove(sibling)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SUBSURFACE_PLACE_ABOVE)
                #expect(unsafe record.object == UnsafeMutableRawPointer(subsurface.pointer))
                #expect(unsafe record.sibling == sibling.pointer)
            }
        }

        @Test
        func subsurfacePlaceBelowPreservesSiblingPointer() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subsurface = try testSubsurface(pointer: 0xE401)
                defer { subsurface.destroy() }
                let sibling = try testSurface(pointer: 0xE402)
                defer { sibling.destroy() }

                subsurface.placeBelow(sibling)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SUBSURFACE_PLACE_BELOW)
                #expect(unsafe record.object == UnsafeMutableRawPointer(subsurface.pointer))
                #expect(unsafe record.sibling == sibling.pointer)
            }
        }

        @Test
        func subsurfaceSynchronizationRequestsUseSubsurfacePointer() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subsurface = try testSubsurface(pointer: 0xE501)
                defer { subsurface.destroy() }

                subsurface.setSynchronized()

                let syncRecord = unsafe swl_test_core_request_record()
                #expect(unsafe syncRecord.call_count == 1)
                #expect(unsafe syncRecord.kind == SWL_TEST_CORE_SUBSURFACE_SET_SYNC)
                #expect(
                    unsafe syncRecord.object
                        == UnsafeMutableRawPointer(subsurface.pointer)
                )

                subsurface.setDesynchronized()

                let desyncRecord = unsafe swl_test_core_request_record()
                #expect(unsafe desyncRecord.call_count == 2)
                #expect(
                    unsafe desyncRecord.kind == SWL_TEST_CORE_SUBSURFACE_SET_DESYNC
                )
                #expect(
                    unsafe desyncRecord.object
                        == UnsafeMutableRawPointer(subsurface.pointer)
                )
            }
        }

        @Test
        func destroyRequestsAreIdempotent() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let subsurface = try testSubsurface(pointer: 0xE601)

                subsurface.destroy()
                subsurface.destroy()

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_CORE_SUBSURFACE_DESTROY)
                #expect(unsafe record.object == UnsafeMutableRawPointer(subsurface.pointer))
            }
        }

        private func testSubcompositor(pointer rawPointer: UInt) throws
            -> RawSubcompositor
        {
            try unsafe RawSubcompositor(
                pointer: testPointer(rawPointer),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
            try unsafe RawSurface.testingSurface(
                pointer: testPointer(rawPointer),
                version: 6,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testSubsurface(pointer rawPointer: UInt) throws -> RawSubsurface {
            try unsafe RawSubsurface(pointer: testPointer(rawPointer))
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
