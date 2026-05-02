import Testing

@testable import WaylandClient

@Suite
struct WindowRedrawStateTests {
    @Test
    func contentInvalidationPublishesOnceUntilRedrawIsConsumed() {
        var state = WindowRedrawState()

        #expect(
            state.reduce(.contentInvalidated, bufferAvailable: true)
                == [.publishRedrawRequested]
        )
        #expect(state.isDirty)

        #expect(state.reduce(.contentInvalidated, bufferAvailable: true).isEmpty)
        #expect(state.reduce(.redrawRequestConsumed, bufferAvailable: true).isEmpty)
        #expect(
            state.reduce(.contentInvalidated, bufferAvailable: true)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func redrawRequestConsumedDoesNotRepublishImmediately() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailable: true)

        #expect(state.reduce(.redrawRequestConsumed, bufferAvailable: true).isEmpty)
        #expect(state.isDirty)
    }

    @Test
    func staticContentDoesNotPublishAgainWhenFrameBecomesReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailable: true)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailable: true)
        let drawnGeneration = state.generationForCurrentDraw

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailable: true)
                .isEmpty
        )
        #expect(!state.isDirty)
        #expect(state.reduce(.frameBecameReady, bufferAvailable: true).isEmpty)
    }

    @Test
    func dirtyContentWaitsForFrameBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailable: true)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailable: true)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.presented(generation: drawnGeneration), bufferAvailable: true)

        #expect(state.reduce(.contentInvalidated, bufferAvailable: true).isEmpty)
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailable: true)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func dirtyContentWaitsForBufferBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailable: true)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailable: true)

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailable: false).isEmpty)
        #expect(state.isWaitingForBuffer)
        #expect(
            state.reduce(.bufferBecameAvailable, bufferAvailable: true)
                == [.publishRedrawRequested]
        )
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func cleanStateCannotWaitForBuffer() {
        var state = WindowRedrawState()

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailable: false).isEmpty)
        #expect(!state.isDirty)
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func presentingOlderGenerationKeepsNewerContentDirtyUntilFrameReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailable: true)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailable: true)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.contentInvalidated, bufferAvailable: true)

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailable: true)
                .isEmpty
        )
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailable: true)
                == [.publishRedrawRequested]
        )
    }
}
