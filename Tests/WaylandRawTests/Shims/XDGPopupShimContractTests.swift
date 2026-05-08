import CWaylandProtocols
import Testing

@Suite(.serialized)
struct XDGPopupShimContractTests {
    @Test
    func popupListenerForwardsConfigureGeometry() {
        let data = UnsafeMutableRawPointer(bitPattern: 0x1010)
        let popup = OpaquePointer(bitPattern: 0x2020)
        var record = swl_test_xdg_popup_configure_record()

        unsafe swl_test_xdg_popup_listener_emit_configure(
            data,
            popup,
            11,
            12,
            320,
            240,
            &record
        )

        #expect(record.call_count == 1)
        #expect(record.data == data)
        #expect(record.popup == popup)
        #expect(record.x == 11)
        #expect(record.y == 12)
        #expect(record.width == 320)
        #expect(record.height == 240)
    }

    @Test
    func popupListenerForwardsDoneAndRepositioned() {
        let data = UnsafeMutableRawPointer(bitPattern: 0x3030)
        let popup = OpaquePointer(bitPattern: 0x4040)
        var doneRecord = swl_test_xdg_popup_done_record()
        var repositionedRecord = swl_test_xdg_popup_repositioned_record()

        unsafe swl_test_xdg_popup_listener_emit_done(data, popup, &doneRecord)
        unsafe swl_test_xdg_popup_listener_emit_repositioned(
            data,
            popup,
            77,
            &repositionedRecord
        )

        #expect(doneRecord.call_count == 1)
        #expect(doneRecord.data == data)
        #expect(doneRecord.popup == popup)
        #expect(repositionedRecord.call_count == 1)
        #expect(repositionedRecord.data == data)
        #expect(repositionedRecord.popup == popup)
        #expect(repositionedRecord.token == 77)
    }

    @Test
    func positionerRequestsPreserveArgumentOrder() {
        let positioner = OpaquePointer(bitPattern: 0x5050)

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_SIZE,
            width: 320,
            height: 240
        ) {
            unsafe swl_xdg_positioner_set_size(positioner, 320, 240)
        }

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR_RECT,
            x: 10,
            y: 20,
            width: 30,
            height: 40
        ) {
            unsafe swl_xdg_positioner_set_anchor_rect(positioner, 10, 20, 30, 40)
        }

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR,
            value: 8
        ) {
            unsafe swl_xdg_positioner_set_anchor(positioner, 8)
        }

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_GRAVITY,
            value: 5
        ) {
            unsafe swl_xdg_positioner_set_gravity(positioner, 5)
        }

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_CONSTRAINT_ADJUSTMENT,
            value: 13
        ) {
            unsafe swl_xdg_positioner_set_constraint_adjustment(positioner, 13)
        }

        assertPositionerRequest(
            expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_OFFSET,
            x: -5,
            y: 6
        ) {
            unsafe swl_xdg_positioner_set_offset(positioner, -5, 6)
        }
    }

    @Test
    func popupGrabPreservesSeatAndSerial() {
        let popup = OpaquePointer(bitPattern: 0x6060)
        let seat = OpaquePointer(bitPattern: 0x7070)

        swl_test_xdg_request_recording_begin()
        defer { swl_test_xdg_request_recording_end() }

        unsafe swl_xdg_popup_grab(popup, seat, 123)
        let record = unsafe swl_test_xdg_popup_grab_record()

        #expect(record.call_count == 1)
        #expect(record.popup == popup)
        #expect(record.seat == seat)
        #expect(record.serial == 123)
    }

    @Test
    func popupDestroyWrappersCallMatchingProtocolDestroy() {
        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x8080),
            expectedKind: SWL_TEST_XDG_DESTROY_POSITIONER
        ) { pointer in
            unsafe swl_xdg_positioner_destroy(pointer)
        }

        assertDestroyWrapper(
            object: OpaquePointer(bitPattern: 0x9090),
            expectedKind: SWL_TEST_XDG_DESTROY_POPUP
        ) { pointer in
            unsafe swl_xdg_popup_destroy(pointer)
        }
    }

    private func assertPositionerRequest(
        expectedKind: swl_test_xdg_positioner_request_kind,
        x: Int32 = 0,
        y: Int32 = 0,
        width: Int32 = 0,
        height: Int32 = 0,
        value: UInt32 = 0,
        request: () -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        swl_test_xdg_request_recording_begin()
        defer { swl_test_xdg_request_recording_end() }

        request()
        let record = unsafe swl_test_xdg_positioner_request_record()

        #expect(record.call_count == 1, sourceLocation: sourceLocation)
        #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
        #expect(record.x == x, sourceLocation: sourceLocation)
        #expect(record.y == y, sourceLocation: sourceLocation)
        #expect(record.width == width, sourceLocation: sourceLocation)
        #expect(record.height == height, sourceLocation: sourceLocation)
        #expect(record.value == value, sourceLocation: sourceLocation)
    }

    private func assertDestroyWrapper(
        object: OpaquePointer?,
        expectedKind: swl_test_xdg_destroy_kind,
        destroy: (OpaquePointer?) -> Void,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        swl_test_xdg_request_recording_begin()
        defer { swl_test_xdg_request_recording_end() }

        destroy(object)
        let record = unsafe swl_test_xdg_destroy_record()

        #expect(record.call_count == 1, sourceLocation: sourceLocation)
        #expect(record.kind == expectedKind, sourceLocation: sourceLocation)
        #expect(record.object == UnsafeMutableRawPointer(object), sourceLocation: sourceLocation)
    }
}
