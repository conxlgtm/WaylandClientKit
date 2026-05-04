import CWaylandProtocols
import Testing

@Suite(.serialized)
struct ScaleShimContractTests {
    @Test
    func surfaceListenerForwardsPreferredBufferScalePreservingFactor() {
        let data = UnsafeMutableRawPointer(bitPattern: 0x1001)
        let surface = OpaquePointer(bitPattern: 0x2002)
        var record = swl_test_surface_preferred_buffer_scale_record()

        let emitted = unsafe swl_test_surface_listener_emit_preferred_buffer_scale(
            data,
            surface,
            3,
            &record
        )

        #expect(emitted == 1)
        #expect(record.call_count == 1)
        #expect(record.data == data)
        #expect(record.surface == surface)
        #expect(record.factor == 3)
    }

    @Test
    func fractionalScaleListenerForwardsPreferredScalePreservingNumerator() {
        let data = UnsafeMutableRawPointer(bitPattern: 0x3003)
        let fractionalScale = OpaquePointer(bitPattern: 0x4004)
        var record = swl_test_fractional_preferred_scale_record()

        unsafe swl_test_fractional_scale_listener_emit_preferred_scale(
            data,
            fractionalScale,
            180,
            &record
        )

        #expect(record.call_count == 1)
        #expect(record.data == data)
        #expect(record.fractional_scale == fractionalScale)
        #expect(record.scale == 180)
    }

    @Test
    func viewportSetDestinationPassesWidthThenHeight() {
        let viewport = OpaquePointer(bitPattern: 0x5005)

        swl_test_scale_request_recording_begin()
        defer { swl_test_scale_request_recording_end() }

        unsafe swl_wp_viewport_set_destination(viewport, 640, 480)
        let record = unsafe swl_test_scale_viewport_destination_record()

        #expect(record.call_count == 1)
        #expect(record.viewport == viewport)
        #expect(record.width == 640)
        #expect(record.height == 480)
    }

    @Test
    func scaleDestroyWrappersCallTheMatchingProtocolDestroy() {
        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x6006),
            expectedKind: SWL_TEST_SCALE_DESTROY_VIEWPORT
        ) { pointer in
            unsafe swl_wp_viewport_destroy(pointer)
        }
        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x7007),
            expectedKind: SWL_TEST_SCALE_DESTROY_VIEWPORTER
        ) { pointer in
            unsafe swl_wp_viewporter_destroy(pointer)
        }
        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x8008),
            expectedKind: SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE
        ) { pointer in
            unsafe swl_wp_fractional_scale_v1_destroy(pointer)
        }
        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x9009),
            expectedKind: SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE_MANAGER
        ) { pointer in
            unsafe swl_wp_fractional_scale_manager_v1_destroy(pointer)
        }
    }

    private func assertDestroyWrapper(
        object: OpaquePointer?,
        expectedKind: swl_test_scale_destroy_kind,
        destroy: (OpaquePointer?) -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        swl_test_scale_request_recording_begin()
        defer { swl_test_scale_request_recording_end() }

        destroy(object)
        let record = unsafe swl_test_scale_destroy_record()

        #expect(record.call_count == 1, sourceLocation: sourceLocation)
        #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
        #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
    }
}
