#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Foundation
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawDesktopIntegrationRequestTests {
        @Test
        func toplevelIconNameAssignmentPreservesPointersAndText() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try testIconManager(pointer: 0xF101)
                defer { manager.destroy() }
                let topLevel = try testTopLevel(pointer: 0xF102)
                defer { topLevel.destroy() }

                let icon = try manager.createIcon()
                try icon.setName("org.waylandclientkit.Test")
                manager.setIcon(icon, on: topLevel)

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 3)
                #expect(
                    unsafe record.kind
                        == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON
                )
                #expect(unsafe record.object == UnsafeMutableRawPointer(manager.pointer))
                #expect(unsafe record.toplevel == topLevel.pointer)
                #expect(unsafe record.icon == icon.pointer)
                #expect(icon.state == .assigned)
            }
        }

        @Test
        func toplevelIconRecordsNameText() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let icon = try testIcon(pointer: 0xF201)
                defer { icon.destroy() }

                try icon.setName("org.waylandclientkit.NamedIcon")

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(
                    unsafe record.kind
                        == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_NAME
                )
                #expect(unsafe record.object == UnsafeMutableRawPointer(icon.pointer))
                #expect(unsafe String(cString: record.text) == "org.waylandclientkit.NamedIcon")
            }
        }

        @Test
        func assignedToplevelIconRejectsFurtherMutation() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try testIconManager(pointer: 0xF301)
                defer { manager.destroy() }
                let topLevel = try testTopLevel(pointer: 0xF302)
                defer { topLevel.destroy() }

                let icon = try manager.createIcon()
                manager.setIcon(icon, on: topLevel)

                #expect(throws: RuntimeError.invalidArgument("immutable xdg_toplevel_icon_v1")) {
                    try icon.setName("org.waylandclientkit.LateMutation")
                }
            }
        }

        @Test
        func toplevelIconNilResetUsesNullIcon() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try testIconManager(pointer: 0xF401)
                defer { manager.destroy() }
                let topLevel = try testTopLevel(pointer: 0xF402)
                defer { topLevel.destroy() }

                manager.setIcon(nil, on: topLevel)

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(
                    unsafe record.kind
                        == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON
                )
                #expect(unsafe record.object == UnsafeMutableRawPointer(manager.pointer))
                #expect(unsafe record.toplevel == topLevel.pointer)
                #expect(unsafe record.icon == nil)
            }
        }

        @Test
        func idleInhibitorCreationPreservesManagerAndSurfacePointers() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let manager = try testIdleInhibitManager(pointer: 0xF501)
                defer { manager.destroy() }
                let surface = try testSurface(pointer: 0xF502)
                defer { surface.destroy() }

                let inhibitor = try manager.createInhibitor(surface: surface)
                defer { inhibitor.destroy() }

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(
                    unsafe record.kind
                        == SWL_TEST_DESKTOP_IDLE_INHIBIT_CREATE_INHIBITOR
                )
                #expect(unsafe record.object == UnsafeMutableRawPointer(manager.pointer))
                #expect(unsafe record.surface == surface.pointer)
                #expect(unsafe record.inhibitor == inhibitor.pointer)
            }
        }

        @Test
        func systemBellRingPreservesOptionalSurfacePointer() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let bell = try testSystemBell(pointer: 0xF601)
                defer { bell.destroy() }
                let surface = try testSurface(pointer: 0xF602)
                defer { surface.destroy() }

                bell.ring(surface: surface)

                let record = unsafe swl_test_desktop_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_SYSTEM_BELL_RING)
                #expect(unsafe record.object == UnsafeMutableRawPointer(bell.pointer))
                #expect(unsafe record.surface == surface.pointer)

                bell.ring(surface: nil)

                let nullRecord = unsafe swl_test_desktop_request_record()
                #expect(unsafe nullRecord.call_count == 2)
                #expect(unsafe nullRecord.kind == SWL_TEST_DESKTOP_SYSTEM_BELL_RING)
                #expect(unsafe nullRecord.surface == nil)
            }
        }

        @Test
        func destroyRequestsAreIdempotent() async throws {
            try await recordDesktopRequests {
                swl_test_desktop_request_recording_begin()
                defer { swl_test_desktop_request_recording_end() }

                let inhibitor = try testIdleInhibitor(pointer: 0xF701)

                inhibitor.destroy()
                inhibitor.destroy()

                let record = unsafe swl_test_desktop_destroy_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR)
                #expect(unsafe record.object == UnsafeMutableRawPointer(inhibitor.pointer))
            }
        }

        @Test
        func desktopRequestRecordingGateSerializesConcurrentBodies() async throws {
            let probe = GateConcurrencyProbe()

            try await withThrowingTaskGroup(of: Void.self) { group in
                for index in 0..<8 {
                    group.addTask {
                        try await DesktopRequestRecordingGate.withExclusiveRecording {
                            await probe.enter(index)
                            try await Task.sleep(for: .milliseconds(5))
                            await probe.leave(index)
                        }
                    }
                }

                try await group.waitForAll()
            }

            #expect(await probe.maximumActiveCount == 1)
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

        private func testIconManager(pointer rawPointer: UInt) throws
            -> RawXDGToplevelIconManager
        {
            try unsafe RawXDGToplevelIconManager(
                pointer: testPointer(rawPointer),
                version: 1,
                proxyAdoption: try testAdoptionContext(),
                installListener: false
            )
        }

        private func testIcon(pointer rawPointer: UInt) throws -> RawXDGToplevelIcon {
            try unsafe RawXDGToplevelIcon(pointer: testPointer(rawPointer))
        }

        private func testTopLevel(pointer rawPointer: UInt) throws -> RawXDGTopLevel {
            try unsafe RawXDGTopLevel(
                pointer: testPointer(rawPointer),
                version: 6,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testIdleInhibitManager(pointer rawPointer: UInt) throws
            -> RawIdleInhibitManager
        {
            try unsafe RawIdleInhibitManager(
                pointer: testPointer(rawPointer),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testIdleInhibitor(pointer rawPointer: UInt) throws -> RawIdleInhibitor {
            try unsafe RawIdleInhibitor(pointer: testPointer(rawPointer))
        }

        private func testSystemBell(pointer rawPointer: UInt) throws -> RawSystemBell {
            try unsafe RawSystemBell(
                pointer: testPointer(rawPointer),
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
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

        private func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
            try unsafe RawSurface.testingSurface(
                pointer: testPointer(rawPointer),
                version: 6,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let eventQueue = unsafe RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try testPointer(0xF999)
            )
            return RawProxyAdoptionContext(eventQueue: eventQueue)
        }

        private func testPointer(_ rawPointer: UInt) throws -> OpaquePointer {
            try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        }
    }

    private actor GateConcurrencyProbe {
        private var activeCount = 0
        private var maximumActiveCountStorage = 0

        var maximumActiveCount: Int {
            maximumActiveCountStorage
        }

        func enter(_ index: Int) {
            activeCount += 1
            maximumActiveCountStorage = max(maximumActiveCountStorage, activeCount)
            _ = index
        }

        func leave(_ index: Int) {
            activeCount -= 1
            _ = index
        }
    }
#endif
