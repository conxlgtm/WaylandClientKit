#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct CursorShapeShimContractTests {
        @Test
        func cursorShapeGetPointerUsesManagerAndPointer() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xC001))
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xC002))

            try await assertCursorShapeRequest(
                expectedKind: SWL_TEST_CURSOR_SHAPE_GET_POINTER,
                object: manager
            ) {
                let device = unsafe swl_wp_cursor_shape_manager_v1_get_pointer(
                    manager,
                    pointer
                )
                #expect(unsafe device != nil)
                let record = unsafe swl_test_cursor_shape_request_record()
                #expect(unsafe record.pointer == pointer)
            }
        }

        @Test
        func cursorShapeSetShapePreservesSerialAndShape() async throws {
            let device = try unsafe #require(OpaquePointer(bitPattern: 0xC003))

            try await assertCursorShapeRequest(
                expectedKind: SWL_TEST_CURSOR_SHAPE_SET_SHAPE,
                object: device
            ) {
                unsafe swl_wp_cursor_shape_device_v1_set_shape(device, 88, 9)
                let record = unsafe swl_test_cursor_shape_request_record()
                #expect(unsafe record.serial == 88)
                #expect(unsafe record.shape == 9)
            }
        }

        @Test
        func cursorShapeDestroyUsesDeviceAndManagerTargets() async throws {
            let device = try unsafe #require(OpaquePointer(bitPattern: 0xC004))
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xC005))

            try await assertCursorShapeDestroy(
                expectedKind: SWL_TEST_CURSOR_SHAPE_DESTROY_DEVICE,
                object: device
            ) {
                unsafe swl_wp_cursor_shape_device_v1_destroy(device)
            }
            try await assertCursorShapeDestroy(
                expectedKind: SWL_TEST_CURSOR_SHAPE_DESTROY_MANAGER,
                object: manager
            ) {
                unsafe swl_wp_cursor_shape_manager_v1_destroy(manager)
            }
        }

        @safe
        private func assertCursorShapeRequest(
            expectedKind: swl_test_cursor_shape_request_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await CursorShapeRequestRecordingGate.withExclusiveRecording {
                swl_test_cursor_shape_request_recording_begin()
                defer { swl_test_cursor_shape_request_recording_end() }

                request()

                let record = unsafe swl_test_cursor_shape_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }

        @safe
        private func assertCursorShapeDestroy(
            expectedKind: swl_test_cursor_shape_destroy_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await CursorShapeRequestRecordingGate.withExclusiveRecording {
                swl_test_cursor_shape_request_recording_begin()
                defer { swl_test_cursor_shape_request_recording_end() }

                request()

                let record = unsafe swl_test_cursor_shape_destroy_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }
    }

#endif
