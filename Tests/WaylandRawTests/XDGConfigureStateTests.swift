import Testing

@testable import WaylandRaw

@Suite
struct XDGConfigureStateTests {
    @Test
    func surfaceConfigureLatchesLatestTopLevelState() {
        let state = XDGConfigureState(fallbackSize: TopLevelSize(width: 640, height: 480))

        state.handleConfigureBounds(width: 1_920, height: 1_080)
        state.handleWMCapabilities([.maximize, .fullscreen])
        state.handleTopLevelConfigure(
            width: 800,
            height: 600,
            states: [.activated, .resizing]
        )

        let configure = state.handleSurfaceConfigure(serial: 42)

        #expect(configure.serial == 42)
        #expect(configure.size == TopLevelSize(width: 800, height: 600))
        #expect(configure.states == [.activated, .resizing])
        #expect(configure.bounds == TopLevelSize(width: 1_920, height: 1_080))
        #expect(configure.wmCapabilities == [.maximize, .fullscreen])
    }

    @Test
    func zeroConfigureSizeUsesFallback() {
        let state = XDGConfigureState(fallbackSize: TopLevelSize(width: 320, height: 240))

        state.handleTopLevelConfigure(width: 0, height: 0)

        #expect(
            state.handleSurfaceConfigure(serial: 7).size == TopLevelSize(width: 320, height: 240))
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
