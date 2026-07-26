#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Foundation
    import Testing
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite(
        .enabled(
            if: SoftwarePresentationRequestTestEnvironment.isEnabled,
            """
            Set WAYLAND_DISPLAY and
            WAYLAND_CLIENT_KIT_ENABLE_SOFTWARE_PRESENTATION_REQUEST_TESTS=1
            """
        ),
        .timeLimit(.minutes(1)),
        .tags(.linux, .integration, .liveWayland, .publicAPI),
        .serialized
    )
    struct WindowSoftwarePresentationPublicRequestTests {
        @Test
        func rejectedPreparationsIssueNoSurfaceTransactionRequests() async throws {
            try await withRecordedSoftwarePresentationConnection { window, displayEvents in
                try await exerciseRepeatedSupersessions(window, displayEvents)
                try await exerciseCancellation(window, displayEvents)
                try await exercisePreparationFailure(window, displayEvents)
                try await exerciseDrawFailure(window, displayEvents)
                #expect(try await window.needsRedraw)
                try await exerciseClose(window)
            }
        }
    }

    private func withRecordedSoftwarePresentationConnection(
        _ operation: @Sendable (Window, DisplayEvents) async throws -> Void
    ) async throws {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await PresentationRequestRecordingGate.withExclusiveRecording {
                try await withSoftwarePresentationConnection { display, window in
                    let displayEvents = display.events
                    try await window.show { frame in
                        fillSoftwareFrame(frame, color: 0x0014_2434)
                    }
                    try await waitForSoftwareRedrawRequest(
                        for: window,
                        in: displayEvents,
                        phase: "initial redraw request"
                    )

                    swl_test_core_request_recording_begin_forwarding()
                    swl_test_presentation_request_recording_begin_forwarding()
                    defer { swl_test_presentation_request_recording_end() }
                    defer { swl_test_core_request_recording_end() }

                    try await operation(window, displayEvents)
                    expectNoSurfaceTransactionRequests()
                }
            }
        }
    }

    private func exerciseRepeatedSupersessions(
        _ window: Window,
        _ displayEvents: DisplayEvents
    ) async throws {
        for _ in 0..<16 {
            let gate = SoftwarePreparationRequestGate()
            async let staleOutcome = window.redraw(
                requestPresentationFeedback: true,
                preparing: { reservation in
                    await gate.suspendPreparation()
                    return reservation.id
                },
                { preparedID, frame in
                    try rejectSoftwareDraw(preparedID, frame)
                }
            )
            await gate.waitUntilSuspended()

            async let replacementEvent = softwareRedrawEvent(
                for: window,
                in: displayEvents,
                phase: "repeated supersession replacement"
            ) {
                do {
                    try await window.requestRedraw()
                } catch {
                    await gate.resumePreparation()
                    throw error
                }
                await gate.resumePreparation()
            }
            #expect(try await staleOutcome == .superseded)
            _ = try await replacementEvent
        }
    }

    private func exerciseCancellation(
        _ window: Window,
        _ displayEvents: DisplayEvents
    ) async throws {
        let gate = SoftwarePreparationRequestGate()
        let outcome = try await withThrowingTaskGroup(
            of: SoftwarePresentationOutcome.self
        ) { group in
            group.addTask {
                try await window.redraw(
                    requestPresentationFeedback: true,
                    preparing: { reservation in
                        await gate.suspendPreparation()
                        return reservation.id
                    },
                    { preparedID, frame in
                        try rejectSoftwareDraw(preparedID, frame)
                    }
                )
            }
            await gate.waitUntilSuspended()
            group.cancelAll()

            async let replacementEvent = softwareRedrawEvent(
                for: window,
                in: displayEvents,
                phase: "cancellation replacement"
            ) {
                await gate.resumePreparation()
            }
            let nextOutcome = try await group.next()
            _ = try await replacementEvent
            return try #require(nextOutcome)
        }
        #expect(outcome == .superseded)
    }

    private func exercisePreparationFailure(
        _ window: Window,
        _ displayEvents: DisplayEvents
    ) async throws {
        _ = try await softwareRedrawEvent(
            for: window,
            in: displayEvents,
            phase: "preparation-failure replacement"
        ) {
            do {
                _ = try await window.redraw(
                    requestPresentationFeedback: true,
                    preparing: { _ in
                        throw InjectedSoftwarePreparationFailure()
                    },
                    { preparedID, frame in
                        try rejectSoftwareDraw(preparedID, frame)
                    }
                )
                Issue.record("expected preparation failure")
            } catch is InjectedSoftwarePreparationFailure {
                // The original preparation error must remain observable.
            }
        }
    }

    private func exerciseDrawFailure(
        _ window: Window,
        _ displayEvents: DisplayEvents
    ) async throws {
        _ = try await softwareRedrawEvent(
            for: window,
            in: displayEvents,
            phase: "draw-failure replacement"
        ) {
            do {
                _ = try await window.redraw(
                    requestPresentationFeedback: true,
                    preparing: { _ in () },
                    { _, _ in
                        throw InjectedSoftwareDrawFailure()
                    }
                )
                Issue.record("expected draw failure")
            } catch let failure as WindowSoftwareDrawFailure {
                #expect(failure.underlying is InjectedSoftwareDrawFailure)
            }
        }
    }

    private func exerciseClose(_ window: Window) async throws {
        let gate = SoftwarePreparationRequestGate()
        async let outcome = window.redraw(
            requestPresentationFeedback: true,
            preparing: { reservation in
                await gate.suspendPreparation()
                return reservation.id
            },
            { preparedID, frame in
                try rejectSoftwareDraw(preparedID, frame)
            }
        )
        await gate.waitUntilSuspended()
        await window.close()
        await gate.resumePreparation()
        #expect(try await outcome == .closed)
    }

    private func expectNoSurfaceTransactionRequests() {
        let coreRecord = unsafe swl_test_core_request_record()
        let presentationRecord = unsafe swl_test_presentation_request_record()

        #expect(unsafe coreRecord.attach_sequence == 0)
        #expect(unsafe coreRecord.frame_sequence == 0)
        #expect(unsafe coreRecord.damage_sequence == 0)
        #expect(unsafe coreRecord.commit_sequence == 0)
        #expect(unsafe presentationRecord.call_count == 0)
    }

    private func withSoftwarePresentationConnection(
        _ body: @Sendable (WaylandDisplay, Window) async throws -> Void
    ) async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.SoftwarePresentationRequestTests",
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Software Presentation Request Test",
                    appID: "wayland-client-kit-software-presentation-request-test",
                    initialWidth: 160,
                    initialHeight: 120,
                    bufferCount: 3,
                    closeRequestPolicy: .requestOnly,
                    decorationPreference: .preferServerSide
                )
            )
            try await body(display, window)
        }
    }

    private func waitForSoftwareRedrawRequest(
        for window: Window,
        in displayEvents: DisplayEvents,
        phase: String
    ) async throws {
        _ = try await softwareRedrawEvent(
            for: window,
            in: displayEvents,
            phase: phase
        ) {
            try await window.requestRedraw()
        }
    }

    private func softwareRedrawEvent(
        for window: Window,
        in displayEvents: DisplayEvents,
        phase: String,
        after trigger: @escaping @Sendable () async throws -> Void
    ) async throws -> DisplayEvent {
        try await withThrowingTaskGroup(of: DisplayEvent.self) { group in
            group.addTask {
                var iterator = displayEvents.makeAsyncIterator()
                try await trigger()
                while let event = try await iterator.next() {
                    if event == .redrawRequested(window.id) {
                        return event
                    }
                }
                throw SoftwarePresentationRequestTestError.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw SoftwarePresentationRequestTestError.timeout(phase)
            }

            let event = try await group.next()
            group.cancelAll()
            return try #require(event)
        }
    }

    private func fillSoftwareFrame(_ frame: borrowing SoftwareFrame, color: UInt32) {
        frame.withXRGB8888Rows { _, pixels in
            for index in 0..<pixels.count {
                unsafe pixels[unchecked: index] = color
            }
        }
    }

    private func rejectSoftwareDraw(
        _ preparedID: SoftwareFrameBufferID,
        _ frame: borrowing SoftwareFrame
    ) throws {
        _ = preparedID
        _ = frame.id
        throw UnexpectedSoftwarePresentationDraw()
    }

    private actor SoftwarePreparationRequestGate {
        private var isSuspended = false
        private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
        private var resumeContinuation: CheckedContinuation<Void, Never>?

        func suspendPreparation() async {
            isSuspended = true
            let waiters = suspensionWaiters
            suspensionWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
            await withCheckedContinuation { continuation in
                resumeContinuation = continuation
            }
        }

        func waitUntilSuspended() async {
            guard !isSuspended else { return }
            await withCheckedContinuation { continuation in
                suspensionWaiters.append(continuation)
            }
        }

        func resumePreparation() {
            resumeContinuation?.resume()
            resumeContinuation = nil
        }
    }

    private enum SoftwarePresentationRequestTestError: Error {
        case streamEnded
        case timeout(String)
    }

    private enum SoftwarePresentationRequestTestEnvironment {
        static var isEnabled: Bool {
            let environment = ProcessInfo.processInfo.environment
            return environment["WAYLAND_DISPLAY"]?.isEmpty == false
                && environment[
                    "WAYLAND_CLIENT_KIT_ENABLE_SOFTWARE_PRESENTATION_REQUEST_TESTS"
                ] == "1"
        }
    }

    private struct UnexpectedSoftwarePresentationDraw: Error {}
    private struct InjectedSoftwarePreparationFailure: Error {}
    private struct InjectedSoftwareDrawFailure: Error {}
#endif
