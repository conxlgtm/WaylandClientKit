#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient
    @testable import WaylandRaw

    @Suite(.serialized)
    struct ToplevelDragCleanupTests {
        @Test
        func terminalDataTransferEventDestroysToplevelDrag() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let sourceID = DataSourceID(rawValue: 41)
                let dragID = ToplevelDragID(rawValue: 42)
                let windowID = WindowID(rawValue: 43)
                let dragPointer = try unsafe testPointer(0xC801)
                let rawDrag = RawXDGToplevelDrag(pointer: dragPointer)

                core.toplevelDragsByID[dragID] = DisplayToplevelDragRecord(
                    id: dragID,
                    windowID: windowID,
                    source: sourceID.dragIdentity,
                    seatID: SeatID(rawValue: 44),
                    serial: InputSerial(rawValue: 45),
                    rawDrag: rawDrag
                )
                core.toplevelDragIDsByWindowID[windowID] = [dragID]

                core.publishDataTransferEvents([
                    .dragSourceCancelled(sourceID.dragIdentity)
                ])

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG)
                #expect(
                    unsafe record.object == UnsafeMutableRawPointer(dragPointer)
                )
                #expect(core.toplevelDragsByID[dragID] == nil)
                #expect(core.toplevelDragIDsByWindowID[windowID] == nil)
            }
        }

        private func recordDesktopRequests(_ request: () async throws -> Void)
            async throws
        {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                try await XDGRequestRecordingGate.withExclusiveRecording {
                    try await DesktopRequestRecordingGate.withExclusiveRecording {
                        swl_test_core_request_recording_begin()
                        swl_test_xdg_request_recording_begin()
                        swl_test_desktop_request_recording_begin()
                        defer {
                            swl_test_desktop_request_recording_end()
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
