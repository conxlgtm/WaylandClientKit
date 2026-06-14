#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @Suite(.serialized)
    struct PointerWarpShimContractTests {
        @Test
        func pointerWarpRequestPreservesSurfacePointerCoordinatesAndSerial() throws {
            let warp = try unsafe #require(OpaquePointer(bitPattern: 0xB111))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xB112))
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xB113))

            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                unsafe swl_wp_pointer_warp_v1_warp_pointer(
                    warp,
                    surface,
                    pointer,
                    384,
                    -128,
                    99
                )
                let record = unsafe swl_test_pointer_capture_request_record()

                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_WARP_POINTER)
                #expect(unsafe record.object == UnsafeMutableRawPointer(warp))
                #expect(unsafe record.surface == UnsafeMutableRawPointer(surface))
                #expect(unsafe record.pointer == UnsafeMutableRawPointer(pointer))
                #expect(unsafe record.x == 384)
                #expect(unsafe record.y == -128)
                #expect(unsafe record.serial == 99)
            }
        }

        @Test
        func pointerWarpDestroyWrapperUsesMatchingTarget() throws {
            let warp = try unsafe #require(OpaquePointer(bitPattern: 0xB606))

            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                unsafe swl_wp_pointer_warp_v1_destroy(warp)
                let record = unsafe swl_test_pointer_capture_destroy_record()

                #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_DESTROY_POINTER_WARP)
                #expect(unsafe record.object == UnsafeMutableRawPointer(warp))
            }
        }
    }

#endif
