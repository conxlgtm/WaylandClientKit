#if SWL_ENABLE_TESTING
    // swiftlint:disable file_length
    import CWaylandProtocols
    import Foundation
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient

    // swiftlint:disable type_body_length
    @Suite(
        .enabled(
            if: DesktopIntegrationRequestTestEnvironment.isEnabled,
            "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_DESKTOP_REQUEST_TESTS=1"
        ),
        .timeLimit(.minutes(1)),
        .tags(.linux, .integration, .liveWayland, .publicAPI),
        .serialized
    )
    struct DesktopIntegrationPublicRequestTests {
        @Test
        func windowSetNamedIconSendsNameSetsIconCommitsAndDestroysTemporaryObjects()
            async throws
        {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().xdgToplevelIcon,
                    "xdg-toplevel-icon"
                )
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )

                let record = try await recordDesktopAndCoreRequests {
                    try await window.setIcon(
                        .named(
                            try WindowIconName("org.waylandclientkit.Test")
                        )
                    )
                }

                #expect(record.desktop.callCount == 3)
                #expect(record.desktop.kind == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON)
                #expect(record.desktop.topLevelAddress == topLevelPointer)
                #expect(record.desktop.iconAddress != nil)
                #expect(record.core.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(record.desktopDestroy.callCount == 1)
                #expect(
                    record.desktopDestroy.kind
                        == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON
                )
            }
        }

        @Test
        func windowSetPixelIconAddsBufferSetsIconCommitsAndDestroysTemporaryObjects()
            async throws
        {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().xdgToplevelIcon,
                    "xdg-toplevel-icon"
                )
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )
                let image = try WindowIconImage.solid(
                    size: try PositivePixelSize(width: 16, height: 16),
                    scale: try PositiveInt32(2),
                    color: 0x0040_80C0
                )

                let record = try await recordDesktopAndCoreRequests {
                    try await window.setIcon(.xrgb8888(image))
                }

                #expect(record.desktop.callCount == 3)
                #expect(record.desktop.kind == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON)
                #expect(record.desktop.topLevelAddress == topLevelPointer)
                #expect(record.desktop.iconAddress != nil)
                #expect(record.desktop.bufferAddress != nil)
                #expect(record.desktop.scale == 2)
                #expect(record.core.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(record.desktopDestroy.callCount == 1)
                #expect(
                    record.desktopDestroy.kind
                        == SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON
                )
            }
        }

        @Test
        func windowSetIconNoneResetsIconAndCommits() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().xdgToplevelIcon,
                    "xdg-toplevel-icon"
                )
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )

                let record = try await recordDesktopAndCoreRequests {
                    try await window.setIcon(.none)
                }

                #expect(record.desktop.callCount == 1)
                #expect(record.desktop.kind == SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON)
                #expect(record.desktop.topLevelAddress == topLevelPointer)
                #expect(record.desktop.iconAddress == nil)
                #expect(record.core.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(record.desktopDestroy.callCount == 0)
            }
        }

        @Test
        func unavailableDesktopProtocolsThrowTypedErrorsThroughPublicAPIs() async throws {
            // swiftlint:disable:next closure_body_length
            try await withDesktopConnection { display, window in
                let capabilities = try await display.capabilities()
                guard
                    !capabilities.xdgToplevelIcon.isAvailable
                        || !capabilities.idleInhibit.isAvailable
                        || !capabilities.systemBell.isAvailable
                else {
                    try Test.cancel("Desktop integration protocols are all advertised.")
                }

                if !capabilities.xdgToplevelIcon.isAvailable {
                    do {
                        try await window.setIcon(.none)
                        Issue.record("Expected xdg-toplevel-icon unavailable error.")
                    } catch ClientError.display(.xdgToplevelIconUnavailable) {
                        // Expected on compositors without xdg-toplevel-icon.
                    } catch {
                        Issue.record("Expected xdg-toplevel-icon unavailable, got \(error).")
                    }
                }

                if !capabilities.idleInhibit.isAvailable {
                    do {
                        _ = try await window.inhibitIdle()
                        Issue.record("Expected idle-inhibit unavailable error.")
                    } catch ClientError.display(.idleInhibitUnavailable) {
                        // Expected on compositors without idle-inhibit.
                    } catch {
                        Issue.record("Expected idle-inhibit unavailable, got \(error).")
                    }
                }

                if !capabilities.systemBell.isAvailable {
                    do {
                        try await display.ringSystemBell()
                        Issue.record("Expected system-bell unavailable error.")
                    } catch ClientError.display(.systemBellUnavailable) {
                        // Expected on compositors without system-bell.
                    } catch {
                        Issue.record("Expected system-bell unavailable, got \(error).")
                    }
                }
            }
        }

        @Test
        func inhibitIdleCreatesSurfaceScopedInhibitor() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().idleInhibit,
                    "idle-inhibit"
                )
                let surfacePointer = try await requireSurfacePointer(in: display, for: window)

                let (_, record) = try await recordDesktopRequests {
                    let inhibitor = try await window.inhibitIdle()
                    try await inhibitor.destroy()
                }

                #expect(record.desktop.callCount == 1)
                #expect(
                    record.desktop.kind
                        == SWL_TEST_DESKTOP_IDLE_INHIBIT_CREATE_INHIBITOR
                )
                #expect(record.desktop.surfaceAddress == surfacePointer)
                #expect(record.desktop.inhibitorAddress != nil)
                #expect(record.desktopDestroy.callCount == 2)
                #expect(
                    record.desktopDestroy.kind
                        == SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR
                )
            }
        }

        @Test
        func destroyIdleInhibitorIsIdempotentAfterKnownDestroy() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().idleInhibit,
                    "idle-inhibit"
                )
                let inhibitor = try await window.inhibitIdle()

                let (_, record) = try await recordDesktopRequests {
                    try await inhibitor.destroy()
                    try await inhibitor.destroy()
                }

                #expect(record.desktopDestroy.callCount == 1)
                #expect(
                    record.desktopDestroy.kind
                        == SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR
                )
            }
        }

        @Test
        func closingWindowDestroysIdleInhibitorsAndSurface() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().idleInhibit,
                    "idle-inhibit"
                )
                _ = try await window.inhibitIdle()

                let record = try await recordDesktopAndCoreRequests {
                    await window.close()
                }

                #expect(record.desktopDestroy.callCount == 1)
                #expect(
                    record.desktopDestroy.kind
                        == SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR
                )
                #expect(record.core.kind == SWL_TEST_CORE_SURFACE_DESTROY)
            }
        }

        @Test
        func createDialogRejectsSelfParentBeforeProtocolRequest() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().xdgDialog,
                    "xdg-dialog"
                )

                do {
                    _ = try await window.createDialog(parent: window, modal: false)
                    Issue.record("Expected self-parent dialog to throw.")
                } catch ClientError.display(
                    .invalidDialogParent(let childID, let parentID)
                ) {
                    #expect(childID == window.id)
                    #expect(parentID == window.id)
                } catch {
                    Issue.record("Expected invalid dialog parent, got \(error).")
                }
            }
        }

        @Test
        func ringDisplaySystemBellUsesNilSurface() async throws {
            try await withDesktopConnection { display, _ in
                try requireAvailable(
                    try await display.capabilities().systemBell,
                    "system-bell"
                )

                let (_, record) = try await recordDesktopRequests {
                    try await display.ringSystemBell()
                }

                #expect(record.desktop.callCount == 1)
                #expect(record.desktop.kind == SWL_TEST_DESKTOP_SYSTEM_BELL_RING)
                #expect(record.desktop.surfaceAddress == nil)
            }
        }

        @Test
        func ringWindowSystemBellUsesWindowSurface() async throws {
            try await withDesktopConnection { display, window in
                try requireAvailable(
                    try await display.capabilities().systemBell,
                    "system-bell"
                )
                let surfacePointer = try await requireSurfacePointer(in: display, for: window)

                let (_, record) = try await recordDesktopRequests {
                    try await window.ringSystemBell()
                }

                #expect(record.desktop.callCount == 1)
                #expect(record.desktop.kind == SWL_TEST_DESKTOP_SYSTEM_BELL_RING)
                #expect(record.desktop.surfaceAddress == surfacePointer)
            }
        }

        @Test
        func desktopIntegrationRejectsForeignWindow() async throws {
            try await WaylandDisplay.withConnection(
                applicationID: "org.waylandclientkit.DesktopIntegrationTests",
                cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
                discoveryTimeoutMilliseconds: 5_000
            ) { firstDisplay in
                try await WaylandDisplay.withConnection(
                    applicationID: "org.waylandclientkit.DesktopIntegrationTests.Second",
                    cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
                    discoveryTimeoutMilliseconds: 5_000
                ) { secondDisplay in
                    let foreignWindow = try await createTestWindow(
                        in: secondDisplay,
                        title: "WaylandClientKit Desktop Foreign Window"
                    )

                    do {
                        _ = try await firstDisplay.inhibitIdle(window: foreignWindow)
                        Issue.record("Expected foreign idle-inhibit window to throw.")
                    } catch ClientError.display(.foreignWindow(let windowID)) {
                        #expect(windowID == foreignWindow.id)
                    } catch {
                        Issue.record("Expected foreign window error, got \(error).")
                    }

                    do {
                        try await firstDisplay.ringSystemBell(window: foreignWindow)
                        Issue.record("Expected foreign system-bell window to throw.")
                    } catch ClientError.display(.foreignWindow(let windowID)) {
                        #expect(windowID == foreignWindow.id)
                    } catch {
                        Issue.record("Expected foreign window error, got \(error).")
                    }
                }
            }
        }
    }
    // swiftlint:enable type_body_length

    private func withDesktopConnection(
        _ body: @Sendable (WaylandDisplay, Window) async throws -> Void
    ) async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.DesktopIntegrationTests",
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let window = try await createTestWindow(
                in: display,
                title: "WaylandClientKit Desktop Integration Request Test"
            )

            try await body(display, window)
        }
    }

    private func createTestWindow(
        in display: WaylandDisplay,
        title: String
    ) async throws -> Window {
        try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: title,
                appID: "wayland-client-kit-desktop-request-test",
                initialWidth: 160,
                initialHeight: 120,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferServerSide
            )
        )
    }

    private func requireTopLevelPointer(
        in display: WaylandDisplay,
        for window: Window
    ) async throws -> UInt {
        guard
            let pointer = try await display.rawTopLevelPointerAddressForTesting(window.id)
        else {
            Issue.record("Expected a live xdg_toplevel for \(window.id).")
            throw DesktopIntegrationRequestTestError.missingTopLevel
        }

        return pointer
    }

    private func requireSurfacePointer(
        in display: WaylandDisplay,
        for window: Window
    ) async throws -> UInt {
        guard
            let pointer = try await display.rawSurfacePointerAddressForTesting(window.id)
        else {
            Issue.record("Expected a live wl_surface for \(window.id).")
            throw DesktopIntegrationRequestTestError.missingSurface
        }

        return pointer
    }

    private func requireAvailable(
        _ availability: ProtocolAvailability,
        _ feature: String
    ) throws {
        guard availability.isAvailable else {
            try Test.cancel("\(feature) is unavailable.")
        }
    }

    private func recordDesktopRequests<Result>(
        _ request: @Sendable () async throws -> Result
    ) async throws -> (Result, RecordedDesktopRequestSet) {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await DesktopRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin_forwarding()
                swl_test_desktop_request_recording_begin_forwarding()
                defer {
                    swl_test_desktop_request_recording_end()
                    swl_test_core_request_recording_end()
                }

                let result = try await request()
                let records = unsafe RecordedDesktopRequestSet(
                    desktop: swl_test_desktop_request_record(),
                    desktopDestroy: swl_test_desktop_destroy_record()
                )
                return (result, records)
            }
        }
    }

    private func recordDesktopAndCoreRequests(
        _ request: @Sendable () async throws -> Void
    ) async throws -> RecordedDesktopAndCoreRequestSet {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await DesktopRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin_forwarding()
                swl_test_desktop_request_recording_begin_forwarding()
                defer {
                    swl_test_desktop_request_recording_end()
                    swl_test_core_request_recording_end()
                }

                try await request()
                return unsafe RecordedDesktopAndCoreRequestSet(
                    core: swl_test_core_request_record(),
                    desktop: swl_test_desktop_request_record(),
                    desktopDestroy: swl_test_desktop_destroy_record()
                )
            }
        }
    }

    private struct RecordedDesktopAndCoreRequestSet: Sendable {
        let core: RecordedCoreRequest
        let desktop: RecordedDesktopRequest
        let desktopDestroy: RecordedDesktopDestroyRequest

        init(
            core coreRecord: swl_test_core_request_record,
            desktop desktopRecord: swl_test_desktop_request_record,
            desktopDestroy desktopDestroyRecord: swl_test_desktop_destroy_record
        ) {
            core = unsafe RecordedCoreRequest(coreRecord)
            desktop = unsafe RecordedDesktopRequest(desktopRecord)
            desktopDestroy = unsafe RecordedDesktopDestroyRequest(desktopDestroyRecord)
        }
    }

    private struct RecordedDesktopRequestSet: Sendable {
        let desktop: RecordedDesktopRequest
        let desktopDestroy: RecordedDesktopDestroyRequest

        init(
            desktop desktopRecord: swl_test_desktop_request_record,
            desktopDestroy desktopDestroyRecord: swl_test_desktop_destroy_record
        ) {
            desktop = unsafe RecordedDesktopRequest(desktopRecord)
            desktopDestroy = unsafe RecordedDesktopDestroyRequest(desktopDestroyRecord)
        }
    }

    private struct RecordedCoreRequest: Sendable {
        let kind: swl_test_core_request_kind

        init(_ record: swl_test_core_request_record) {
            unsafe kind = record.kind
        }
    }

    private struct RecordedDesktopRequest: Sendable {
        let callCount: Int32
        let kind: swl_test_desktop_request_kind
        let topLevelAddress: UInt?
        let iconAddress: UInt?
        let bufferAddress: UInt?
        let surfaceAddress: UInt?
        let inhibitorAddress: UInt?
        let scale: Int32

        init(_ record: swl_test_desktop_request_record) {
            unsafe callCount = record.call_count
            unsafe kind = record.kind
            unsafe topLevelAddress = Self.pointerAddress(record.toplevel)
            unsafe iconAddress = Self.pointerAddress(record.icon)
            unsafe bufferAddress = Self.pointerAddress(record.buffer)
            unsafe surfaceAddress = Self.pointerAddress(record.surface)
            unsafe inhibitorAddress = Self.pointerAddress(record.inhibitor)
            unsafe scale = record.scale
        }

        private static func pointerAddress(_ pointer: OpaquePointer?) -> UInt? {
            guard let pointer = unsafe pointer else { return nil }

            return unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
        }
    }

    private struct RecordedDesktopDestroyRequest: Sendable {
        let callCount: Int32
        let kind: swl_test_desktop_destroy_kind

        init(_ record: swl_test_desktop_destroy_record) {
            unsafe callCount = record.call_count
            unsafe kind = record.kind
        }
    }

    private enum DesktopIntegrationRequestTestError: Error {
        case missingSurface
        case missingTopLevel
    }

    private enum DesktopIntegrationRequestTestEnvironment {
        static var isEnabled: Bool {
            let environment = ProcessInfo.processInfo.environment

            return environment["WAYLAND_DISPLAY"]?.isEmpty == false
                && environment["WAYLAND_CLIENT_KIT_ENABLE_DESKTOP_REQUEST_TESTS"] == "1"
        }
    }
#endif
