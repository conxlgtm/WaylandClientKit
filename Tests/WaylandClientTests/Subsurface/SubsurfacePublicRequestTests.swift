#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Foundation
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite(
        .enabled(
            if: SubsurfaceRequestTestEnvironment.isEnabled,
            "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_SUBSURFACE_REQUEST_TESTS=1"
        ),
        .timeLimit(.minutes(1)),
        .tags(.linux, .integration, .liveWayland, .publicAPI),
        .serialized
    )
    struct SubsurfacePublicRequestTests {
        @Test
        func createSubsurfaceCommitsParentAfterChildSetup() async throws {
            try await withSubsurfaceConnection { display, window in
                let probe = try await installParentCommitProbe(in: display, for: window)
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )

                #expect(probe.count == 1)
                await subsurface.close()
            }
        }

        @Test
        func synchronizedSubsurfaceShowCommitsChildThenParent() async throws {
            try await withSubsurfaceConnection { display, window in
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration(synchronizationMode: .synchronized)
                )
                let probe = try await installParentCommitProbe(in: display, for: window)
                probe.reset()

                try await subsurface.show(drawSolid)

                #expect(probe.count == 1)
                await subsurface.close()
            }
        }

        @Test
        func desynchronizedSubsurfaceShowDoesNotCommitParent() async throws {
            try await withSubsurfaceConnection { display, window in
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration(synchronizationMode: .desynchronized)
                )
                let probe = try await installParentCommitProbe(in: display, for: window)
                probe.reset()

                try await subsurface.show(drawSolid)

                #expect(probe.count == 0)
                await subsurface.close()
            }
        }

        @Test
        func setPositionCommitsParentAfterParentWasDrawn() async throws {
            try await withSubsurfaceConnection { display, window in
                try await window.show(timeoutMilliseconds: 5_000, drawSolid)
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )
                let probe = try await installParentCommitProbe(in: display, for: window)
                probe.reset()

                try await subsurface.setPosition(LogicalOffset(x: 24, y: 18))

                #expect(probe.count == 1)
            }
        }

        @Test
        func placeAboveRejectsSelfBeforeRawRequest() async throws {
            try await withSubsurfaceConnection { _, window in
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )
                let record = try await recordCoreRequest {
                    do {
                        try await subsurface.placeAbove(subsurface)
                        Issue.record("Expected self-stacking to throw.")
                    } catch ClientError.display(
                        .invalidSubsurfaceStacking(let error)
                    ) {
                        #expect(error == .selfReference(subsurface.id))
                    } catch {
                        Issue.record("Expected self-stacking error, got \(error).")
                    }
                }

                #expect(record.callCount == 0)
                #expect(record.kind == SWL_TEST_CORE_REQUEST_NONE)
            }
        }

        @Test
        func crossParentStackingRejectsBeforeRawRequest() async throws {
            try await withSubsurfaceConnection { display, window in
                let otherWindow = try await createTestWindow(
                    in: display,
                    title: "SwiftWayland Subsurface Other Parent"
                )
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )
                let sibling = try await otherWindow.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )
                let record = try await recordCoreRequest {
                    do {
                        try await subsurface.placeBelow(sibling)
                        Issue.record("Expected cross-parent stacking to throw.")
                    } catch ClientError.display(.invalidSubsurfaceStacking(let error)) {
                        #expect(
                            error
                                == .differentParent(
                                    subsurface: subsurface.id,
                                    sibling: sibling.id
                                )
                        )
                    } catch {
                        Issue.record("Expected cross-parent stacking error, got \(error).")
                    }
                }

                #expect(record.callCount == 0)
                #expect(record.kind == SWL_TEST_CORE_REQUEST_NONE)
            }
        }

        @Test
        func closingParentClosesManagedSubsurfacesBeforeParentSurfaceDestroy() async throws {
            try await withSubsurfaceConnection { _, window in
                let subsurface = try await window.createSubsurface(
                    configuration: subsurfaceConfiguration()
                )

                await window.close()

                do {
                    try await subsurface.setPosition(LogicalOffset(x: 1, y: 1))
                    Issue.record("Expected closed subsurface handle to throw.")
                } catch ClientError.display(.closedSubsurface) {
                    // Expected after parent close removes the child graph.
                } catch {
                    Issue.record("Expected closed subsurface error, got \(error).")
                }
            }
        }
    }

    private func withSubsurfaceConnection(
        _ body: @Sendable (WaylandDisplay, Window) async throws -> Void
    ) async throws {
        try await WaylandDisplay.withConnection(
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let window = try await createTestWindow(
                in: display,
                title: "SwiftWayland Subsurface Request Test"
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
                appID: "swift-wayland-subsurface-request-test",
                initialWidth: 160,
                initialHeight: 120,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferServerSide
            )
        )
    }

    private func subsurfaceConfiguration(
        synchronizationMode: SubsurfaceSynchronizationMode = .synchronized
    ) throws -> SubsurfaceConfiguration {
        SubsurfaceConfiguration(
            position: LogicalOffset(x: 8, y: 8),
            size: try PositiveLogicalSize(width: 48, height: 48),
            synchronizationMode: synchronizationMode
        )
    }

    private func installParentCommitProbe(
        in display: WaylandDisplay,
        for window: Window
    ) async throws -> ParentCommitProbe {
        let probe = ParentCommitProbe()
        try await display.installSubsurfaceParentCommitObserverForTesting(
            windowID: window.id
        ) {
            probe.record()
        }

        return probe
    }

    private func recordCoreRequest(
        _ request: () async throws -> Void,
        cleanup: () async -> Void = {}
    ) async throws -> RecordedCoreRequest {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            swl_test_core_request_recording_begin()
            swl_test_buffer_listener_recording_begin()
            defer {
                swl_test_buffer_listener_recording_end()
                swl_test_core_request_recording_end()
            }

            do {
                try await request()
                let record = unsafe RecordedCoreRequest(swl_test_core_request_record())
                await cleanup()
                return record
            } catch {
                await cleanup()
                throw error
            }
        }
    }

    private func recordCoreRequest<Result>(
        _ request: () async throws -> Result,
        cleanup: (Result) async -> Void
    ) async throws -> (Result, RecordedCoreRequest) {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            swl_test_core_request_recording_begin()
            swl_test_buffer_listener_recording_begin()
            defer {
                swl_test_buffer_listener_recording_end()
                swl_test_core_request_recording_end()
            }

            let result = try await request()
            let record = unsafe RecordedCoreRequest(swl_test_core_request_record())
            await cleanup(result)
            return (result, record)
        }
    }

    private func drawSolid(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { _, pixels in
            for x in 0..<Int(frame.width) {
                unsafe pixels[unchecked: x] = 0x0030_6090
            }
        }
    }

    private struct RecordedCoreRequest: Sendable {
        let callCount: Int32
        let kind: swl_test_core_request_kind

        init(_ record: swl_test_core_request_record) {
            unsafe callCount = record.call_count
            unsafe kind = record.kind
        }
    }

    private final class ParentCommitProbe: @unchecked Sendable {
        private var countStorage = 0

        var count: Int {
            countStorage
        }

        func record() {
            countStorage += 1
        }

        func reset() {
            countStorage = 0
        }
    }

    private enum SubsurfaceRequestTestEnvironment {
        static var isEnabled: Bool {
            let environment = ProcessInfo.processInfo.environment

            return environment["WAYLAND_DISPLAY"]?.isEmpty == false
                && environment["SWIFT_WAYLAND_ENABLE_SUBSURFACE_REQUEST_TESTS"] == "1"
        }
    }

#endif
