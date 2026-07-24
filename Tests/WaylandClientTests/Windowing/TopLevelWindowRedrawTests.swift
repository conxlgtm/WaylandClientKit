import Testing

@testable import WaylandClient

@Suite
struct TopLevelWindowRedrawTests {
    @Test
    func pendingConfigurePublishesRedrawWithoutOldBuffer() {
        var redraw = WindowRedrawState()
        let availability = TopLevelWindow.resolveRedrawBufferAvailability(
            hasPendingSurfaceConfigure: true,
            currentBufferAvailability: {
                Issue.record("The old buffer pool should not be checked.")
                return .unavailable
            }()
        )

        let effects = redraw.reduce(
            .contentInvalidated,
            bufferAvailability: availability
        )

        #expect(effects == [.publishRedrawRequested])
    }

    @Test
    func unavailableBufferWithoutPendingConfigureWaits() {
        var redraw = WindowRedrawState()
        let availability = TopLevelWindow.resolveRedrawBufferAvailability(
            hasPendingSurfaceConfigure: false,
            currentBufferAvailability: .unavailable
        )

        let effects = redraw.reduce(
            .contentInvalidated,
            bufferAvailability: availability
        )

        #expect(effects.isEmpty)
        #expect(redraw.isWaitingForBuffer)
    }
}
