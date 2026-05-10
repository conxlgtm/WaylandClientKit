import CWaylandProtocols
import Testing

@Suite(.serialized)
struct ScaleShimContractTests {
    @Test
    func surfaceListenerForwardsPreferredBufferScalePreservingFactor() {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x1001)
        let surface = unsafe OpaquePointer(bitPattern: 0x2002)
        var record = unsafe swl_test_surface_preferred_buffer_scale_record()
        let emitted = unsafe swl_test_surface_listener_emit_preferred_buffer_scale(
            data,
            surface,
            3,
            &record
        )
        #expect(emitted == 1)
        #expect(unsafe record.call_count == 1)
        #expect(unsafe record.data == data)
        #expect(unsafe record.surface == surface)
        #expect(unsafe record.factor == 3)
    }

    @Test
    func surfaceListenerForwardsOutputEnterAndLeave() {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x1101)
        let surface = unsafe OpaquePointer(bitPattern: 0x2202)
        let output = unsafe OpaquePointer(bitPattern: 0x3303)
        var enterRecord = unsafe swl_test_surface_output_record()
        var leaveRecord = unsafe swl_test_surface_output_record()

        unsafe swl_test_surface_listener_emit_enter(
            data,
            surface,
            output,
            &enterRecord
        )
        unsafe swl_test_surface_listener_emit_leave(
            data,
            surface,
            output,
            &leaveRecord
        )

        #expect(unsafe enterRecord.call_count == 1)
        #expect(unsafe enterRecord.data == data)
        #expect(unsafe enterRecord.surface == surface)
        #expect(unsafe enterRecord.output == output)
        #expect(unsafe leaveRecord.call_count == 1)
        #expect(unsafe leaveRecord.data == data)
        #expect(unsafe leaveRecord.surface == surface)
        #expect(unsafe leaveRecord.output == output)
    }

    @Test
    func fractionalScaleListenerForwardsPreferredScalePreservingNumerator() {
        let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x3003)
        let fractionalScale = unsafe OpaquePointer(bitPattern: 0x4004)
        var record = unsafe swl_test_fractional_preferred_scale_record()
        unsafe swl_test_fractional_scale_listener_emit_preferred_scale(
            data,
            fractionalScale,
            180,
            &record
        )
        #expect(unsafe record.call_count == 1)
        #expect(unsafe record.data == data)
        #expect(unsafe record.fractional_scale == fractionalScale)
        #expect(unsafe record.scale == 180)
    }
    @Test
    func viewportSetDestinationPassesWidthThenHeight() {
        let viewport = unsafe OpaquePointer(bitPattern: 0x5005)
        swl_test_scale_request_recording_begin()
        defer { swl_test_scale_request_recording_end() }
        unsafe swl_wp_viewport_set_destination(viewport, 640, 480)
        let record = unsafe swl_test_scale_viewport_destination_record()
        #expect(unsafe record.call_count == 1)
        #expect(unsafe record.viewport == viewport)
        #expect(unsafe record.width == 640)
        #expect(unsafe record.height == 480)
    }
    @Test
    func scaleDestroyWrappersCallTheMatchingProtocolDestroy() {
        assertDestroyWrapper(
            object: unsafe OpaquePointer(bitPattern: 0x6006),
            expectedKind: SWL_TEST_SCALE_DESTROY_VIEWPORT
        ) { pointer in
            unsafe swl_wp_viewport_destroy(pointer)
        }
        assertDestroyWrapper(
            object: unsafe OpaquePointer(bitPattern: 0x7007),
            expectedKind: SWL_TEST_SCALE_DESTROY_VIEWPORTER
        ) { pointer in
            unsafe swl_wp_viewporter_destroy(pointer)
        }
        assertDestroyWrapper(
            object: unsafe OpaquePointer(bitPattern: 0x8008),
            expectedKind: SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE
        ) { pointer in
            unsafe swl_wp_fractional_scale_v1_destroy(pointer)
        }
        assertDestroyWrapper(
            object: unsafe OpaquePointer(bitPattern: 0x9009),
            expectedKind: SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE_MANAGER
        ) { pointer in
            unsafe swl_wp_fractional_scale_manager_v1_destroy(pointer)
        }
    }
    @safe
    private func assertDestroyWrapper(
        object: OpaquePointer?,
        expectedKind: swl_test_scale_destroy_kind,
        destroy: (OpaquePointer?) -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        swl_test_scale_request_recording_begin()
        defer { swl_test_scale_request_recording_end() }
        unsafe destroy(object)
        let record = unsafe swl_test_scale_destroy_record()
        let expectedObject = unsafe UnsafeMutableRawPointer(object)
        #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
        #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
        #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
    }
}
