import Testing

@testable import WaylandClient

@Suite
struct WindowRedrawStateTests {
    @Test
    func contentInvalidationPublishesOnceUntilRedrawIsConsumed() {
        var state = WindowRedrawState()

        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(state.isDirty)

        #expect(state.reduce(.contentInvalidated, bufferAvailability: .available).isEmpty)
        #expect(state.reduce(.redrawRequestConsumed, bufferAvailability: .available).isEmpty)
        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func redrawRequestConsumedDoesNotRepublishImmediately() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)

        #expect(state.reduce(.redrawRequestConsumed, bufferAvailability: .available).isEmpty)
        #expect(state.isDirty)
    }

    @Test
    func staticContentDoesNotPublishAgainWhenFrameBecomesReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)
                .isEmpty
        )
        #expect(!state.isDirty)
        #expect(state.reduce(.frameBecameReady, bufferAvailability: .available).isEmpty)
    }

    @Test
    func dirtyContentWaitsForFrameBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)

        #expect(state.reduce(.contentInvalidated, bufferAvailability: .available).isEmpty)
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func dirtyContentWaitsForBufferBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable).isEmpty)
        #expect(state.isWaitingForBuffer)
        #expect(
            state.reduce(.bufferBecameAvailable, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func contentInvalidatedWaitingForBufferWithAvailableReplacementPublishes() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        _ = state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable)

        #expect(state.isWaitingForBuffer)
        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(!state.isWaitingForBuffer)
        #expect(state.hasOutstandingRedrawRequest)
    }

    @Test
    func contentInvalidatedWaitingForBufferWithoutReplacementKeepsWaiting() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        _ = state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable)

        #expect(state.isWaitingForBuffer)
        #expect(state.reduce(.contentInvalidated, bufferAvailability: .unavailable).isEmpty)
        #expect(state.isWaitingForBuffer)
    }

    @Test
    func cleanStateCannotWaitForBuffer() {
        var state = WindowRedrawState()

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable).isEmpty)
        #expect(!state.isDirty)
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func presentingOlderGenerationKeepsNewerContentDirtyUntilFrameReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)
                .isEmpty
        )
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }
}
