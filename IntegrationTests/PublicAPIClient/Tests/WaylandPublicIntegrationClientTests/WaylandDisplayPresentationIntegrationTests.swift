import Testing
import WaylandClient

@Suite(
    "WaylandDisplay presentation integration",
    .enabled(
        if: PublicIntegrationEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1"
    ),
    .serialized
)
struct WaylandDisplayPresentationIntegrationTests {
    @Test
    func presentationFeedbackReportsUnavailableOrPublishesResult() async throws {
        try await withPublicConnection { display in
            let capabilities = try await display.capabilities()
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )

            try await show(window, color: 0x0014_2434)

            if capabilities.presentationTime.isAvailable {
                try await expectPresentationFeedback(from: window)
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
        noteOptionalProtocolSkip(
            test: "presentation feedback",
            interfaceName: "wp_presentation"
        )
    } catch {
        Issue.record("Expected presentation-time error, got \(error)")
    }
}

private func expectPresentationFeedback(from window: Window) async throws {
    let presentationEvents = window.presentationEvents

    try await window.requestPresentationFeedback()
    try await window.requestRedraw()
    try await window.redraw { frame in
        fill(frame, color: 0x0044_2414)
    }

    let feedback = try await withTimeout(
        nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
        operation: "waiting for presentation feedback"
    ) {
        try await nextPresentationFeedback(in: presentationEvents)
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
    in events: WindowPresentationEvents
) async throws -> SurfacePresentationFeedback? {
    var iterator = events.makeAsyncIterator()
    return try await iterator.next()
}
