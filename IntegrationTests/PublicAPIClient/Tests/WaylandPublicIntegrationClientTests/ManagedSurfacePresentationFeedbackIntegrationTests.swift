import Testing
import WaylandClient

@Suite(
    "Managed surface presentation feedback integration",
    .enabled(
        if: PublicIntegrationEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS=1"
    ),
    .timeLimit(.minutes(1)),
    .serialized
)
struct ManagedPresentationFeedbackTests {
    @Test
    func subsurfaceCreationPublishesManagedRedrawEvent() async throws {
        try await withPublicConnection { display in
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )
            try await window.show { frame in fill(frame, color: 0x0012_1212) }

            let event = try await displayEvent(
                in: display.events,
                matching: { event in
                    if case .redrawRequested(.subsurface) = event { return true }
                    return false
                },
                after: {
                    _ = try await window.createSubsurface(
                        configuration: SubsurfaceConfiguration(
                            position: LogicalOffset(x: 4, y: 4),
                            size: try PositiveLogicalSize(width: 32, height: 32)
                        )
                    )
                }
            )
            guard case .redrawRequested(.subsurface) = event else {
                Issue.record("Expected a managed subsurface redraw event")
                return
            }
            await window.close()
        }
    }

    @Test
    func popupAndSubsurfaceFeedbackReachRootAndFilteredStreams() async throws {
        try await withPublicConnection { display in
            try await exerciseManagedFeedback(on: display)
        }
    }

    private func exerciseManagedFeedback(on display: WaylandDisplay) async throws {
        let capabilities = try await display.capabilities()
        guard capabilities.presentationTime.isAvailable else {
            try noteOptionalProtocolSkip(
                test: "managed surface presentation feedback",
                interfaceName: "wp_presentation"
            )
            return
        }

        let window = try await display.createTopLevelWindow(
            configuration: testWindowConfiguration()
        )
        let windowOutcome = try await window.show { frame in
            fill(frame, color: 0x0012_2436)
        }
        #expect(windowOutcome == .presented)

        let popup = try await window.createPopup(configuration: testPopupConfiguration())
        try await expectFeedback(
            from: popup.presentationEvents,
            surface: .popup(popup.id),
            rootEvents: display.events
        ) {
            try await popup.show(requestPresentationFeedback: true) { frame in
                fill(frame, color: 0x0036_2412)
            }
        }

        let subsurface = try await window.createSubsurface(
            configuration: SubsurfaceConfiguration(
                position: LogicalOffset(x: 8, y: 8),
                size: try PositiveLogicalSize(width: 48, height: 48),
                synchronizationMode: .synchronized
            )
        )
        try await expectFeedback(
            from: subsurface.presentationEvents,
            surface: .subsurface(subsurface.identity),
            rootEvents: display.events
        ) {
            try await subsurface.show(requestPresentationFeedback: true) { frame in
                fill(frame, color: 0x0024_3612)
            }
        }

        await popup.close()
        await subsurface.close()
        await window.close()
    }

    private func expectFeedback(
        from filteredEvents: ManagedSurfacePresentationEvents,
        surface: ManagedSurfaceIdentity,
        rootEvents: DisplayEvents,
        presenting: () async throws -> SoftwarePresentationOutcome
    ) async throws {
        let subscriptionGate = ManagedFeedbackSubscriptionGate(requiredCount: 2)
        async let rootEvent = nextRootPresentation(
            in: rootEvents,
            matching: surface,
            gate: subscriptionGate
        )
        async let filteredFeedback = nextFilteredPresentation(
            in: filteredEvents,
            gate: subscriptionGate
        )
        await subscriptionGate.waitUntilReady()
        #expect(try await presenting() == .presented)

        let (resolvedRootEvent, resolvedFilteredFeedback) = try await (
            rootEvent,
            filteredFeedback
        )
        #expect(resolvedRootEvent.feedback == resolvedFilteredFeedback)
    }

    private func nextRootPresentation(
        in events: DisplayEvents,
        matching surface: ManagedSurfaceIdentity,
        gate: ManagedFeedbackSubscriptionGate
    ) async throws -> ManagedSurfacePresentationEvent {
        try await withTimeout(
            nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
            operation: "waiting for managed root presentation feedback"
        ) {
            var iterator = events.makeAsyncIterator()
            await gate.arrive()
            while let event = try await iterator.next() {
                if case .presentation(let presentation) = event,
                    presentation.surface == surface
                {
                    return presentation
                }
            }
            throw PublicIntegrationError.streamEnded
        }
    }

    private func nextFilteredPresentation(
        in events: ManagedSurfacePresentationEvents,
        gate: ManagedFeedbackSubscriptionGate
    ) async throws -> SurfacePresentationFeedback {
        try await withTimeout(
            nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
            operation: "waiting for managed filtered presentation feedback"
        ) {
            var iterator = events.makeAsyncIterator()
            await gate.arrive()
            guard let feedback = try await iterator.next() else {
                throw PublicIntegrationError.streamEnded
            }
            return feedback
        }
    }
}

private actor ManagedFeedbackSubscriptionGate {
    private let requiredCount: Int
    private var count = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(requiredCount: Int) {
        self.requiredCount = requiredCount
    }

    func arrive() {
        count += 1
        guard count >= requiredCount else { return }
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }

    func waitUntilReady() async {
        guard count < requiredCount else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}
