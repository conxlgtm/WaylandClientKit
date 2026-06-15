#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct RawDesktopRelationshipRequestTests {
        @Test
        func xdgDialogRequestsPreserveManagerDialogAndToplevelPointers() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try unsafe testPointer(0xFA01)
                let topLevel = try unsafe testPointer(0xFA02)

                let dialog = unsafe swl_xdg_wm_dialog_v1_get_xdg_dialog(manager, topLevel)
                let createRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe dialog != nil)
                #expect(unsafe createRecord.call_count == 1)
                #expect(unsafe createRecord.kind == SWL_TEST_DESKTOP_DIALOG_GET)
                #expect(unsafe createRecord.object == UnsafeMutableRawPointer(manager))
                #expect(unsafe createRecord.toplevel == topLevel)
                #expect(unsafe createRecord.dialog == dialog)

                unsafe swl_xdg_dialog_v1_set_modal(dialog)
                let setRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe setRecord.call_count == 2)
                #expect(unsafe setRecord.kind == SWL_TEST_DESKTOP_DIALOG_SET_MODAL)
                #expect(unsafe setRecord.object == UnsafeMutableRawPointer(dialog))

                unsafe swl_xdg_dialog_v1_unset_modal(dialog)
                let unsetRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe unsetRecord.call_count == 3)
                #expect(unsafe unsetRecord.kind == SWL_TEST_DESKTOP_DIALOG_UNSET_MODAL)
                #expect(unsafe unsetRecord.object == UnsafeMutableRawPointer(dialog))
            }
        }

        @Test
        func toplevelDragRequestsPreserveSourceToplevelAndOffsets() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try unsafe testPointer(0xFA11)
                let source = try unsafe testPointer(0xFA12)
                let topLevel = try unsafe testPointer(0xFA13)

                let drag = unsafe swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(
                    manager,
                    source
                )
                let createRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe drag != nil)
                #expect(unsafe createRecord.call_count == 1)
                #expect(unsafe createRecord.kind == SWL_TEST_DESKTOP_TOPLEVEL_DRAG_GET)
                #expect(unsafe createRecord.object == UnsafeMutableRawPointer(manager))
                #expect(unsafe createRecord.data_source == source)
                #expect(unsafe createRecord.drag == drag)

                unsafe swl_xdg_toplevel_drag_v1_attach(drag, topLevel, -7, 9)
                let attachRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe attachRecord.call_count == 2)
                #expect(unsafe attachRecord.kind == SWL_TEST_DESKTOP_TOPLEVEL_DRAG_ATTACH)
                #expect(unsafe attachRecord.object == UnsafeMutableRawPointer(drag))
                #expect(unsafe attachRecord.toplevel == topLevel)
                #expect(unsafe attachRecord.x == -7)
                #expect(unsafe attachRecord.y == 9)
            }
        }

        @Test
        func foreignToplevelListStopRecordsTarget() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let list = try unsafe testPointer(0xFA21)
                unsafe swl_ext_foreign_toplevel_list_v1_stop(list)

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_FOREIGN_TOPLEVEL_LIST_STOP)
                #expect(unsafe record.object == UnsafeMutableRawPointer(list))
            }
        }

        private func recordDesktopRequests(
            _ request: @Sendable () async throws -> Void
        ) async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                try await XDGRequestRecordingGate.withExclusiveRecording {
                    try await DesktopRequestRecordingGate.withExclusiveRecording {
                        swl_test_core_request_recording_begin()
                        swl_test_xdg_request_recording_begin()
                        defer {
                            swl_test_xdg_request_recording_end()
                            swl_test_core_request_recording_end()
                        }

                        try await request()
                    }
                }
            }
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
