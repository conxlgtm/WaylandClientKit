import Testing

@testable import WaylandRaw

@Suite
struct XDGConfigureStateTests {
    @Test
    func surfaceConfigureLatchesLatestTopLevelState() {
        let state = XDGConfigureState()

        state.handleConfigureBounds(width: 1_920, height: 1_080)
        state.handleWMCapabilities([.maximize, .fullscreen])
        state.handleTopLevelConfigure(
            width: 800,
            height: 600,
            states: [.activated, .resizing]
        )

        let configure = state.handleSurfaceConfigure(serial: 42)

        #expect(configure.serial == 42)
        #expect(configure.topLevel.size == TopLevelSize(width: 800, height: 600))
        #expect(configure.topLevel.states == [.activated, .resizing])
        #expect(configure.topLevel.bounds == TopLevelSize(width: 1_920, height: 1_080))
        #expect(configure.topLevel.wmCapabilities == [.maximize, .fullscreen])
    }

    @Test
    func zeroConfigureSizeIsPreservedAsProtocolFact() {
        let state = XDGConfigureState()

        state.handleTopLevelConfigure(width: 0, height: 0)

        #expect(
            state.handleSurfaceConfigure(serial: 7).topLevel.size
                == TopLevelSize(width: 0, height: 0))
    }

    @Test
    func partialZeroConfigureSizeIsPreservedPerDimension() {
        let state = XDGConfigureState()

        state.handleTopLevelConfigure(width: 0, height: 720)

        #expect(
            state.handleSurfaceConfigure(serial: 7).topLevel.size
                == TopLevelSize(width: 0, height: 720))
    }

    @Test
    func zeroConfigureBoundsClearsBoundsInsteadOfUsingFallback() {
        let state = XDGConfigureState()
        state.handleConfigureBounds(width: 1_024, height: 768)
        state.handleConfigureBounds(width: 0, height: 0)

        #expect(state.handleSurfaceConfigure(serial: 8).topLevel.bounds == nil)
    }

    @Test
    func partialZeroConfigureBoundsClearsBounds() {
        let state = XDGConfigureState()
        state.handleConfigureBounds(width: 1_024, height: 0)

        #expect(state.handleSurfaceConfigure(serial: 9).topLevel.bounds == nil)
    }

    @Test
    func pendingCallbackErrorsAreThrownAndCleared() {
        let state = XDGConfigureState()
        state.recordError(.invalidWaylandArrayByteCount(byteCount: 3, elementSize: 4))

        do {
            try state.throwPendingErrorIfAny()
            Issue.record("Expected pending XDG configure error")
        } catch RuntimeError.invalidWaylandArrayByteCount(let byteCount, let elementSize) {
            #expect(byteCount == 3)
            #expect(elementSize == 4)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        do {
            try state.throwPendingErrorIfAny()
        } catch {
            Issue.record("Expected pending error to be cleared, got \(error)")
        }
    }
}
