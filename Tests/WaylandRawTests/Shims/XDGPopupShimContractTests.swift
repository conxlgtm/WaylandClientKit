#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct XDGPopupShimContractTests {
        @Test
        func popupListenerForwardsConfigureGeometry() {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x1010)
            let popup = unsafe OpaquePointer(bitPattern: 0x2020)
            var record = unsafe swl_test_xdg_popup_configure_record()
            unsafe swl_test_xdg_popup_listener_emit_configure(
                data,
                popup,
                11,
                12,
                320,
                240,
                &record
            )
            #expect(unsafe record.call_count == 1)
            #expect(unsafe record.data == data)
            #expect(unsafe record.popup == popup)
            #expect(unsafe record.x == 11)
            #expect(unsafe record.y == 12)
            #expect(unsafe record.width == 320)
            #expect(unsafe record.height == 240)
        }
        @Test
        func popupListenerForwardsDoneAndRepositioned() {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x3030)
            let popup = unsafe OpaquePointer(bitPattern: 0x4040)
            var doneRecord = unsafe swl_test_xdg_popup_done_record()
            var repositionedRecord = unsafe swl_test_xdg_popup_repositioned_record()
            unsafe swl_test_xdg_popup_listener_emit_done(data, popup, &doneRecord)
            unsafe swl_test_xdg_popup_listener_emit_repositioned(
                data,
                popup,
                77,
                &repositionedRecord
            )
            #expect(unsafe doneRecord.call_count == 1)
            #expect(unsafe doneRecord.data == data)
            #expect(unsafe doneRecord.popup == popup)
            #expect(unsafe repositionedRecord.call_count == 1)
            #expect(unsafe repositionedRecord.data == data)
            #expect(unsafe repositionedRecord.popup == popup)
            #expect(unsafe repositionedRecord.token == 77)
        }
        @Test
        func positionerRequestsPreserveArgumentOrder() async throws {
            let positioner = unsafe OpaquePointer(bitPattern: 0x5050)
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_SIZE,
                width: 320,
                height: 240
            ) {
                unsafe swl_xdg_positioner_set_size(positioner, 320, 240)
            }
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR_RECT,
                x: 10,
                y: 20,
                width: 30,
                height: 40
            ) {
                unsafe swl_xdg_positioner_set_anchor_rect(positioner, 10, 20, 30, 40)
            }
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR,
                value: 8
            ) {
                unsafe swl_xdg_positioner_set_anchor(positioner, 8)
            }
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_GRAVITY,
                value: 5
            ) {
                unsafe swl_xdg_positioner_set_gravity(positioner, 5)
            }
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_CONSTRAINT_ADJUSTMENT,
                value: 13
            ) {
                unsafe swl_xdg_positioner_set_constraint_adjustment(positioner, 13)
            }
            try await assertPositionerRequest(
                expectedKind: SWL_TEST_XDG_POSITIONER_REQUEST_OFFSET,
                x: -5,
                y: 6
            ) {
                unsafe swl_xdg_positioner_set_offset(positioner, -5, 6)
            }
        }
        @Test
        func popupGrabPreservesSeatAndSerial() async throws {
            let popup = unsafe OpaquePointer(bitPattern: 0x6060)
            let seat = unsafe OpaquePointer(bitPattern: 0x7070)
            try await XDGRequestRecordingGate.withExclusiveRecording {
                swl_test_xdg_request_recording_begin()
                defer { swl_test_xdg_request_recording_end() }
                unsafe swl_xdg_popup_grab(popup, seat, 123)
                let record = unsafe swl_test_xdg_popup_grab_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.popup == popup)
                #expect(unsafe record.seat == seat)
                #expect(unsafe record.serial == 123)
            }
        }
        @Test
        func popupDestroyWrappersCallMatchingProtocolDestroy() async throws {
            try await assertDestroyWrapper(
                object: unsafe OpaquePointer(bitPattern: 0x8080),
                expectedKind: SWL_TEST_XDG_DESTROY_POSITIONER
            ) { pointer in
                unsafe swl_xdg_positioner_destroy(pointer)
            }
            try await assertDestroyWrapper(
                object: unsafe OpaquePointer(bitPattern: 0x9090),
                expectedKind: SWL_TEST_XDG_DESTROY_POPUP
            ) { pointer in
                unsafe swl_xdg_popup_destroy(pointer)
            }
        }
        @safe
        private func assertPositionerRequest(
            expectedKind: swl_test_xdg_positioner_request_kind,
            x: Int32 = 0,
            y: Int32 = 0,
            width: Int32 = 0,
            height: Int32 = 0,
            value: UInt32 = 0,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            try await XDGRequestRecordingGate.withExclusiveRecording {
                swl_test_xdg_request_recording_begin()
                defer { swl_test_xdg_request_recording_end() }
                request()
                let record = unsafe swl_test_xdg_positioner_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.x == x, sourceLocation: sourceLocation)
                #expect(unsafe record.y == y, sourceLocation: sourceLocation)
                #expect(unsafe record.width == width, sourceLocation: sourceLocation)
                #expect(unsafe record.height == height, sourceLocation: sourceLocation)
                #expect(unsafe record.value == value, sourceLocation: sourceLocation)
            }
        }
        @safe
        private func assertDestroyWrapper(
            object: OpaquePointer?,
            expectedKind: swl_test_xdg_destroy_kind,
            destroy: (OpaquePointer?) -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            try await XDGRequestRecordingGate.withExclusiveRecording {
                swl_test_xdg_request_recording_begin()
                defer { swl_test_xdg_request_recording_end() }
                unsafe destroy(object)
                let record = unsafe swl_test_xdg_destroy_record()
                let expectedObject = unsafe UnsafeMutableRawPointer(object)
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == expectedObject, sourceLocation: sourceLocation)
            }
        }
    }

#endif
