#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct XDGTopLevelShimContractTests {
        @Test
        func identityRequestsPreserveText() async throws {
            let topLevel = unsafe OpaquePointer(bitPattern: 0x1010)

            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_TITLE,
                topLevel: topLevel,
                text: "WaylandClientKit"
            ) {
                unsafe swl_xdg_toplevel_set_title(topLevel, "WaylandClientKit")
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_APP_ID,
                topLevel: topLevel,
                text: "dev.waylandclientkit.tests"
            ) {
                unsafe swl_xdg_toplevel_set_app_id(topLevel, "dev.waylandclientkit.tests")
            }
        }

        @Test
        func interactiveRequestsPreserveSeatSerialAndGeometry() async throws {
            let topLevel = unsafe OpaquePointer(bitPattern: 0x1111)
            let seat = unsafe OpaquePointer(bitPattern: 0x2222)

            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SHOW_WINDOW_MENU,
                topLevel: topLevel,
                seat: seat,
                serial: 123,
                x: 10,
                y: -20
            ) {
                unsafe swl_xdg_toplevel_show_window_menu(topLevel, seat, 123, 10, -20)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_MOVE,
                topLevel: topLevel,
                seat: seat,
                serial: 456
            ) {
                unsafe swl_xdg_toplevel_move(topLevel, seat, 456)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_RESIZE,
                topLevel: topLevel,
                seat: seat,
                serial: 789,
                value: 10
            ) {
                unsafe swl_xdg_toplevel_resize(topLevel, seat, 789, 10)
            }
        }

        @Test
        func sizeLimitRequestsPreserveDimensions() async throws {
            let topLevel = unsafe OpaquePointer(bitPattern: 0x3333)

            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAX_SIZE,
                topLevel: topLevel,
                width: 1_920,
                height: 1_080
            ) {
                unsafe swl_xdg_toplevel_set_max_size(topLevel, 1_920, 1_080)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE,
                topLevel: topLevel,
                width: 320,
                height: 240
            ) {
                unsafe swl_xdg_toplevel_set_min_size(topLevel, 320, 240)
            }
        }

        @Test
        func windowStateRequestsPreserveProtocolRequest() async throws {
            let topLevel = unsafe OpaquePointer(bitPattern: 0x4444)
            let output = unsafe OpaquePointer(bitPattern: 0x5555)

            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAXIMIZED,
                topLevel: topLevel
            ) {
                unsafe swl_xdg_toplevel_set_maximized(topLevel)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_MAXIMIZED,
                topLevel: topLevel
            ) {
                unsafe swl_xdg_toplevel_unset_maximized(topLevel)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_FULLSCREEN,
                topLevel: topLevel,
                output: output
            ) {
                unsafe swl_xdg_toplevel_set_fullscreen(topLevel, output)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_FULLSCREEN,
                topLevel: topLevel
            ) {
                unsafe swl_xdg_toplevel_unset_fullscreen(topLevel)
            }
            try await assertTopLevelRequest(
                expectedKind: SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MINIMIZED,
                topLevel: topLevel
            ) {
                unsafe swl_xdg_toplevel_set_minimized(topLevel)
            }
        }

        @safe
        private func assertTopLevelRequest(
            expectedKind: swl_test_xdg_toplevel_request_kind,
            topLevel: OpaquePointer?,
            seat: OpaquePointer? = nil,
            output: OpaquePointer? = nil,
            serial: UInt32 = 0,
            x: Int32 = 0,
            y: Int32 = 0,
            width: Int32 = 0,
            height: Int32 = 0,
            value: UInt32 = 0,
            text: String? = nil,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            try await XDGRequestRecordingGate.withExclusiveRecording {
                swl_test_xdg_request_recording_begin()
                defer { swl_test_xdg_request_recording_end() }

                request()

                let record = unsafe swl_test_xdg_toplevel_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.toplevel == topLevel, sourceLocation: sourceLocation)
                #expect(unsafe record.seat == seat, sourceLocation: sourceLocation)
                #expect(unsafe record.output == output, sourceLocation: sourceLocation)
                #expect(unsafe record.serial == serial, sourceLocation: sourceLocation)
                #expect(unsafe record.x == x, sourceLocation: sourceLocation)
                #expect(unsafe record.y == y, sourceLocation: sourceLocation)
                #expect(unsafe record.width == width, sourceLocation: sourceLocation)
                #expect(unsafe record.height == height, sourceLocation: sourceLocation)
                #expect(unsafe record.value == value, sourceLocation: sourceLocation)
                let recordedText = unsafe record.text.map { unsafe String(cString: $0) }
                #expect(recordedText == text, sourceLocation: sourceLocation)
            }
        }
    }

#endif
