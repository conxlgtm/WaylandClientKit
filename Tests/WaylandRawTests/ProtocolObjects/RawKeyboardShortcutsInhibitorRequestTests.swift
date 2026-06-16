#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawKeyboardShortcutsInhibitorRequestTests {
        @Test
        func listenerInstallFailureDestroysAdoptedInhibitor() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                try ShimRequestRecordingLock.pointerCapture.withLock { _ in
                    try assertListenerInstallFailureDestroysAdoptedInhibitor()
                }
            }
        }

        private func assertListenerInstallFailureDestroysAdoptedInhibitor()
            throws
        {
            swl_test_core_request_recording_begin()
            swl_test_pointer_capture_request_recording_begin()
            swl_test_keyboard_shortcuts_inhibitor_listener_set_add_result(-1)
            defer {
                swl_test_keyboard_shortcuts_inhibitor_listener_set_add_result(0)
                swl_test_pointer_capture_request_recording_end()
                swl_test_core_request_recording_end()
            }

            let manager = try testManager(pointer: 0xC101)
            defer { manager.destroy() }
            let surface = try testSurface(pointer: 0xC102)
            defer { surface.destroy() }
            let seat = try RawSeat.testingNoopSeatForRequestRecording(
                id: RawSeatID(rawValue: 1),
                pointerAddress: 0xC103
            )

            #expect(
                throws: RuntimeError.listenerInstallFailed(
                    "zwp_keyboard_shortcuts_inhibitor_v1"
                )
            ) {
                try manager.inhibitShortcuts(surface: surface, seat: seat)
            }

            let destroyRecord = unsafe swl_test_pointer_capture_destroy_record()
            #expect(unsafe destroyRecord.call_count == 1)
            #expect(
                unsafe destroyRecord.kind
                    == SWL_TEST_POINTER_CAPTURE_DESTROY_SHORTCUTS_INHIBITOR
            )
            #expect(
                unsafe destroyRecord.object
                    == UnsafeMutableRawPointer(OpaquePointer(bitPattern: 0xB801))
            )
        }

        private func testManager(pointer rawPointer: UInt) throws
            -> RawKeyboardShortcutsInhibitManager
        {
            try unsafe RawKeyboardShortcutsInhibitManager(
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

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try testPointer(0xC999)
            )
            return RawProxyAdoptionContext(eventQueue: eventQueue)
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
