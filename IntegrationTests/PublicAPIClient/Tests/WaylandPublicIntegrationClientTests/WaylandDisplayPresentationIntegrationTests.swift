import Testing
import WaylandClient

extension WaylandDisplayPublicIntegrationTests {
    @Test
    func asyncSoftwarePresentationSupersedesStalePreparationAndCommitsReplacement() async throws {
        try await withPublicConnection { display in
            try await exerciseStaleSoftwarePresentation(on: display)
        }
    }

    @Test
    func canceledAsyncSoftwarePreparationIsSupersededAndRetryable() async throws {
        try await withPublicConnection { display in
            try await exerciseCanceledSoftwarePresentation(on: display)
        }
    }

    @Test
    func closingWindowDuringAsyncSoftwarePreparationReturnsClosedWithoutDrawing() async throws {
        try await withPublicConnection { display in
            try await exerciseWindowCloseDuringSoftwarePreparation(on: display)
        }
    }

    @Test
    func closingDisplayDuringAsyncSoftwarePreparationReturnsClosedWithoutDrawing() async throws {
        try await withPublicConnection { display in
            try await exerciseDisplayCloseDuringSoftwarePreparation(on: display)
        }
    }

    private func exerciseStaleSoftwarePresentation(on display: WaylandDisplay) async throws {
        let displayEvents = display.events
        let window = try await display.createTopLevelWindow(
            configuration: testWindowConfiguration()
        )

        let initialOutcome = try await window.show(
            timeoutMilliseconds: publicIntegrationTimeoutMilliseconds,
            preparing: { $0.id },
            { preparedID, frame in
                #expect(preparedID == frame.id)
                fill(frame, color: 0x0014_2434)
            }
        )
        #expect(initialOutcome == .presented)
        #expect(
            try await window.redraw(
                preparing: { $0.id },
                { _, _ in throw UnexpectedStaleSoftwareDraw() }
            ) == .deferred
        )
        try await waitForRedrawRequest(for: window, in: displayEvents)

        let gate = AsyncSoftwarePreparationGate()
        async let staleOutcome = window.redraw(
            requestPresentationFeedback: true,
            preparing: { reservation in
                await gate.suspendPreparation()
                return reservation.id
            },
            { _, _ in throw UnexpectedStaleSoftwareDraw() }
        )
        await gate.waitUntilSuspended()

        async let replacementEvent = displayEvent(
            in: displayEvents,
            matching: { $0 == .redrawRequested(.window(window.id)) },
            after: {
                try await window.requestRedraw()
                await gate.resumePreparation()
            }
        )

        #expect(try await staleOutcome == .superseded)
        #expect(try await replacementEvent == .redrawRequested(.window(window.id)))
        #expect(try await window.needsRedraw)
        let replacementOutcome = try await window.redraw(
            preparing: { $0.id },
            { preparedID, frame in
                #expect(preparedID == frame.id)
                fill(frame, color: 0x0044_2414)
            }
        )
        #expect(replacementOutcome == .presented)
        await window.close()
    }

    private func exerciseCanceledSoftwarePresentation(on display: WaylandDisplay) async throws {
        let displayEvents = display.events
        let window = try await display.createTopLevelWindow(
            configuration: testWindowConfiguration()
        )
        try await show(window, color: 0x0024_1424)
        try await waitForRedrawRequest(for: window, in: displayEvents)

        let gate = AsyncSoftwarePreparationGate()
        let outcome = try await withThrowingTaskGroup(
            of: SoftwarePresentationOutcome.self
        ) { group in
            group.addTask {
                try await window.redraw(
                    preparing: { reservation in
                        await gate.suspendPreparation()
                        return reservation.id
                    },
                    { _, _ in throw UnexpectedStaleSoftwareDraw() }
                )
            }
            await gate.waitUntilSuspended()
            group.cancelAll()

            async let replacementEvent = displayEvent(
                in: displayEvents,
                matching: { $0 == .redrawRequested(.window(window.id)) },
                after: { await gate.resumePreparation() }
            )
            let nextOutcome = try await group.next()
            #expect(try await replacementEvent == .redrawRequested(.window(window.id)))
            return try #require(nextOutcome)
        }
        #expect(outcome == .superseded)
        #expect(
            try await window.redraw(
                preparing: { $0.id },
                { _, frame in fill(frame, color: 0x0034_1434) }
            ) == .presented
        )
        await window.close()
    }

    private func exerciseWindowCloseDuringSoftwarePreparation(
        on display: WaylandDisplay
    ) async throws {
        let displayEvents = display.events
        let window = try await display.createTopLevelWindow(
            configuration: testWindowConfiguration()
        )
        try await show(window, color: 0x0011_2233)
        try await waitForRedrawRequest(for: window, in: displayEvents)

        let gate = AsyncSoftwarePreparationGate()
        async let outcome = window.redraw(
            preparing: { reservation in
                await gate.suspendPreparation()
                return reservation.id
            },
            { _, _ in throw UnexpectedStaleSoftwareDraw() }
        )
        await gate.waitUntilSuspended()
        await window.close()
        await gate.resumePreparation()

        #expect(try await outcome == .closed)
        #expect(
            try await window.redraw(
                preparing: { $0.id },
                { _, _ in throw UnexpectedStaleSoftwareDraw() }
            ) == .closed
        )
    }

    private func exerciseDisplayCloseDuringSoftwarePreparation(
        on display: WaylandDisplay
    ) async throws {
        let displayEvents = display.events
        let window = try await display.createTopLevelWindow(
            configuration: testWindowConfiguration()
        )
        try await show(window, color: 0x0011_3344)
        try await waitForRedrawRequest(for: window, in: displayEvents)

        let gate = AsyncSoftwarePreparationGate()
        async let outcome = window.redraw(
            preparing: { reservation in
                await gate.suspendPreparation()
                return reservation.id
            },
            { _, _ in throw UnexpectedStaleSoftwareDraw() }
        )
        await gate.waitUntilSuspended()
        await display.close()
        await gate.resumePreparation()

        #expect(try await outcome == .closed)
    }

    @Test
    func throwingAsyncSoftwarePreparationReleasesReservationAndRepublishesRedraw() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )
            try await show(window, color: 0x0033_2211)
            try await waitForRedrawRequest(for: window, in: displayEvents)

            let replacementEvent = try await displayEvent(
                in: displayEvents,
                matching: { $0 == .redrawRequested(.window(window.id)) },
                after: {
                    do {
                        _ = try await window.redraw(
                            preparing: { _ in throw InjectedSoftwarePreparationFailure() },
                            { _, _ in throw UnexpectedStaleSoftwareDraw() }
                        )
                        Issue.record("expected software preparation failure")
                    } catch is InjectedSoftwarePreparationFailure {
                        // The original preparation failure remains observable.
                    }
                }
            )
            #expect(replacementEvent == .redrawRequested(.window(window.id)))
            #expect(
                try await window.redraw(
                    preparing: { $0.id },
                    { _, frame in fill(frame, color: 0x0022_3344) }
                ) == .presented
            )
            await window.close()
        }
    }

    @Test
    func presentationFeedbackReportsUnavailableOrPublishesResult() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let displayEvents = display.events
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )

            try await show(window, color: 0x0014_2434)

            if capabilities.presentationTime.isAvailable {
                try await expectPresentationFeedback(from: window, events: displayEvents)
            } else {
                try await expectPresentationFeedbackUnavailable(from: window)
            }

            await window.close()
        }
    }
}

private func expectPresentationFeedbackUnavailable(from window: Window) async throws {
    do {
        try await window.requestPresentationFeedback()
        Issue.record("Expected presentation-time unavailable error")
    } catch ClientError.display(.presentationTimeUnavailable) {
        try noteOptionalProtocolSkip(
            test: "presentation feedback",
            interfaceName: "wp_presentation"
        )
    } catch {
        Issue.record("Expected presentation-time error, got \(error)")
    }
}

private func expectPresentationFeedback(
    from window: Window,
    events displayEvents: DisplayEvents
) async throws {
    let presentationEvents = window.presentationEvents

    _ = try await displayEvent(
        in: displayEvents,
        matching: { event in
            event == .redrawRequested(.window(window.id))
        },
        after: {
            try await window.requestRedraw()
        }
    )
    let outcome = try await window.redraw(requestPresentationFeedback: true) { frame in
        fill(frame, color: 0x0044_2414)
    }
    #expect(outcome == .presented)

    let feedback: SurfacePresentationFeedback?
    do {
        feedback = try await withTimeout(
            nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
            operation: "waiting for presentation feedback"
        ) {
            try await nextPresentationFeedback(in: presentationEvents)
        }
    } catch PublicIntegrationError.timeout {
        try noteOptionalProtocolRuntimeSkip(
            test: "presentation feedback",
            interfaceName: "wp_presentation"
        )
        return
    }

    guard let feedback else {
        throw PublicIntegrationError.streamEnded
    }

    switch feedback {
    case .presented(let presentation):
        #expect(presentation.surface == feedback.surface)
    case .discarded(let identity):
        #expect(identity == feedback.surface)
    }
}

private func nextPresentationFeedback(
    in events: ManagedSurfacePresentationEvents
) async throws -> SurfacePresentationFeedback? {
    var iterator = events.makeAsyncIterator()
    return try await iterator.next()
}

private func noteOptionalProtocolRuntimeSkip(test: String, interfaceName: String) throws {
    try Test.cancel(
        "Compositor advertised \(interfaceName) for \(test) but did not deliver a terminal event."
    )
}

private func waitForRedrawRequest(
    for window: Window,
    in displayEvents: DisplayEvents
) async throws {
    _ = try await displayEvent(
        in: displayEvents,
        matching: { $0 == .redrawRequested(.window(window.id)) },
        after: { try await window.requestRedraw() }
    )
}

private actor AsyncSoftwarePreparationGate {
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

private struct UnexpectedStaleSoftwareDraw: Error {}
private struct InjectedSoftwarePreparationFailure: Error {}
