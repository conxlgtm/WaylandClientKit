#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct RawDesktopRelationshipDestroyTests {
        @Test
        func desktopRelationshipDestroyWrappersUseMatchingTargets() async throws {
            let dialogManager = try unsafe testPointer(0xFA31)
            let dialog = try unsafe testPointer(0xFA32)
            let dragManager = try unsafe testPointer(0xFA33)
            let drag = try unsafe testPointer(0xFA34)
            let list = try unsafe testPointer(0xFA35)
            let handle = try unsafe testPointer(0xFA36)

            try await assertDestroyRequest(
                object: dialogManager,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_DIALOG_MANAGER,
                destroy: unsafe swl_xdg_wm_dialog_v1_destroy
            )
            try await assertDestroyRequest(
                object: dialog,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_DIALOG,
                destroy: unsafe swl_xdg_dialog_v1_destroy
            )
            try await assertDestroyRequest(
                object: dragManager,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG_MANAGER,
                destroy: unsafe swl_xdg_toplevel_drag_manager_v1_destroy
            )
            try await assertDestroyRequest(
                object: drag,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG,
                destroy: unsafe swl_xdg_toplevel_drag_v1_destroy
            )
            try await assertDestroyRequest(
                object: list,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_LIST,
                destroy: unsafe swl_ext_foreign_toplevel_list_v1_destroy
            )
            try await assertDestroyRequest(
                object: handle,
                expectedKind: SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_HANDLE,
                destroy: unsafe swl_ext_foreign_toplevel_handle_v1_destroy
            )
        }

        @safe
        private func assertDestroyRequest(
            object rawObject: OpaquePointer,
            expectedKind: swl_test_desktop_destroy_kind,
            destroy: (OpaquePointer?) -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }
                unsafe destroy(rawObject)
                assertDestroy(
                    expectedKind: expectedKind,
                    object: rawObject,
                    sourceLocation: sourceLocation
                )
            }
        }

        private func recordDesktopRequests(_ request: () async throws -> Void) async throws {
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

        @safe
        private func assertDestroy(
            expectedKind: swl_test_desktop_destroy_kind,
            object rawObject: OpaquePointer,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            let record = unsafe swl_test_desktop_destroy_record()
            #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
            #expect(
                unsafe record.object == UnsafeMutableRawPointer(rawObject),
                sourceLocation: sourceLocation
            )
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
