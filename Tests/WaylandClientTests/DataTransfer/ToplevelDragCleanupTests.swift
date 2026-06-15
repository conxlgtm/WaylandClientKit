#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient
    import WaylandRaw

    @Suite(.serialized)
    struct ToplevelDragCleanupTests {
        @Test
        func terminalDataTransferEventDestroysToplevelDrag() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let sourceID = DataSourceID(rawValue: 41)
                let dragID = ToplevelDragID(rawValue: 42)
                let windowID = WindowID(rawValue: 43)
                let dragPointer = UInt(0xC801)
                try installToplevelDrag(
                    in: core,
                    sourceID: sourceID,
                    dragID: dragID,
                    windowID: windowID,
                    pointer: 0xC801
                )

                core.publishDataTransferEvents([
                    .dragSourceCancelled(sourceID.dragIdentity)
                ])

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG)
                #expect(
                    unsafe record.object == UnsafeMutableRawPointer(bitPattern: dragPointer)
                )
                #expect(core.toplevelDragsByID[dragID] == nil)
                #expect(core.toplevelDragIDsByWindowID[windowID] == nil)
            }
        }

        @Test
        func windowCloseKeepsActiveToplevelDragUntilTerminalEvent() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let sourceID = DataSourceID(rawValue: 51)
                let dragID = ToplevelDragID(rawValue: 52)
                let windowID = WindowID(rawValue: 53)
                let dragPointer = UInt(0xC802)
                try installToplevelDrag(
                    in: core,
                    sourceID: sourceID,
                    dragID: dragID,
                    windowID: windowID,
                    pointer: 0xC802
                )

                core.detachToplevelDrags(forClosingWindow: windowID)

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 0)
                #expect(core.toplevelDragsByID[dragID] != nil)
                #expect(core.toplevelDragIDsByWindowID[windowID] == nil)

                core.publishDataTransferEvents([
                    .dragSourceCancelled(sourceID.dragIdentity)
                ])

                let terminalRecord = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe terminalRecord.call_count == 1)
                #expect(unsafe terminalRecord.kind == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG)
                #expect(
                    unsafe terminalRecord.object == UnsafeMutableRawPointer(bitPattern: dragPointer)
                )
                #expect(core.toplevelDragsByID[dragID] == nil)
            }
        }

        @Test
        func installedCancelHookDestroysToplevelDrag() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let manager = DataTransferManager(backend: RecordingDataTransferBackend())
                let sourceID = DataSourceID(rawValue: 61)
                let dragID = ToplevelDragID(rawValue: 62)
                try installToplevelDrag(
                    in: core,
                    sourceID: sourceID,
                    dragID: dragID,
                    windowID: WindowID(rawValue: 63),
                    pointer: 0xC803
                )

                core.installToplevelDragCancellationHook(on: manager)
                manager.sourceWillCancel(sourceID)

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG)
                #expect(core.toplevelDragsByID[dragID] == nil)
            }
        }

        @Test
        func manualCancelRejectsActiveToplevelDrag() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let sourceID = DataSourceID(rawValue: 71)
                let dragID = ToplevelDragID(rawValue: 72)
                try installToplevelDrag(
                    in: core,
                    sourceID: sourceID,
                    dragID: dragID,
                    windowID: WindowID(rawValue: 73),
                    pointer: 0xC804
                )

                #expect(throws: ClientError.display(.toplevelDragStillActive(dragID))) {
                    try core.cancelDragSource(id: sourceID)
                }
                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 0)
            }
        }

        @Test
        func displayCloseDestroysRemainingToplevelDrags() async throws {
            try await recordDesktopRequests {
                let core = DisplayCore(eventHub: DisplayEventHub())
                let sourceID = DataSourceID(rawValue: 81)
                let dragID = ToplevelDragID(rawValue: 82)
                let windowID = WindowID(rawValue: 83)
                let dragPointer = UInt(0xC805)
                try installToplevelDrag(
                    in: core,
                    sourceID: sourceID,
                    dragID: dragID,
                    windowID: windowID,
                    pointer: dragPointer
                )

                core.detachToplevelDrags(forClosingWindow: windowID)
                core.close()

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG)
                #expect(
                    unsafe record.object == UnsafeMutableRawPointer(bitPattern: dragPointer)
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

        private func installToplevelDrag(
            in core: DisplayCore,
            sourceID: DataSourceID,
            dragID: ToplevelDragID,
            windowID: WindowID,
            pointer: UInt
        ) throws {
            let dragPointer = try unsafe testPointer(pointer)
            let rawDrag = RawXDGToplevelDrag.testingToplevelDrag(
                pointer: dragPointer
            )
            core.toplevelDragsByID[dragID] = DisplayToplevelDragRecord(
                id: dragID,
                windowID: windowID,
                source: sourceID.dragIdentity,
                seatID: SeatID(rawValue: 99),
                serial: InputSerial(rawValue: 100),
                rawDrag: rawDrag
            )
            core.toplevelDragIDsByWindowID[windowID] = [dragID]
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }
#endif
