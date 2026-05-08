import Testing

@testable import WaylandRaw

@Suite
struct XDGConfigureStateTests {
    @Test
    func surfaceConfigureLatchesLatestTopLevelState() {
        let state = XDGConfigureState()

        state.handleConfigureBounds(width: 1_920, height: 1_080)
        state.handleWMCapabilities([.maximize, .fullscreen])
        state.handleDecorationConfigure(mode: .serverSide)
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
        #expect(configure.decoration == .changed(.serverSide))
        #expect(configure.decorationMode == .serverSide)
    }

    @Test
    func initialConfigureReceiptFollowsConfigurePhase() {
        let state = XDGConfigureState()

        state.handleTopLevelConfigure(width: 800, height: 600)
        #expect(!state.hasReceivedInitialConfigure)

        _ = state.handleSurfaceConfigure(serial: 1)
        #expect(state.hasReceivedInitialConfigure)

        _ = state.consumeLatestConfigure()
        #expect(state.hasReceivedInitialConfigure)
    }

    @Test
    func decorationConfigureIsConsumedBySurfaceConfigure() {
        let state = XDGConfigureState()
        state.handleDecorationConfigure(mode: .clientSide)

        #expect(state.handleSurfaceConfigure(serial: 1).decorationMode == .clientSide)
        _ = state.consumeLatestConfigure()
        let configure = state.handleSurfaceConfigure(serial: 2)
        #expect(configure.decoration == .unchanged)
        #expect(configure.decorationMode == nil)
    }

    @Test
    func decorationModeSurvivesSkippedSurfaceConfigure() {
        let state = XDGConfigureState()
        state.handleDecorationConfigure(mode: .serverSide)
        _ = state.handleSurfaceConfigure(serial: 1)

        #expect(state.handleSurfaceConfigure(serial: 2).decorationMode == .serverSide)
        #expect(state.consumeLatestConfigure()?.serial == 2)
        #expect(state.handleSurfaceConfigure(serial: 3).decorationMode == nil)
    }

    @Test
    func multipleDecorationConfiguresBetweenSurfaceConfiguresUseLatestMode() {
        let state = XDGConfigureState()
        state.handleDecorationConfigure(mode: .clientSide)
        state.handleDecorationConfigure(mode: .serverSide)

        #expect(state.handleSurfaceConfigure(serial: 1).decorationMode == .serverSide)
    }

    @Test
    func unknownDecorationConfigureModeIsPreserved() throws {
        let state = XDGConfigureState()
        state.handleDecorationConfigure(mode: .serverSide)
        state.handleDecorationConfigure(rawMode: 999)

        try state.throwPendingErrorIfAny()
        #expect(state.handleSurfaceConfigure(serial: 1).decorationMode == .unknown(999))
    }

    @Test
    func rawDecorationModePreservesUnknownMode() throws {
        #expect(try RawDecorationMode(validating: 999) == .unknown(999))
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
    func negativeTopLevelConfigureRecordsProtocolErrorAtRawBoundary() {
        let state = XDGConfigureState()

        state.handleTopLevelConfigure(width: -1, height: 480)

        #expect(throws: RuntimeError.invalidTopLevelConfigureSize(width: -1, height: 480)) {
            try state.throwPendingErrorIfAny()
        }
    }

    @Test
    func zeroConfigureBoundsClearsBoundsInsteadOfUsingFallback() {
        let state = XDGConfigureState()
        state.handleConfigureBounds(width: 1_024, height: 768)
        state.handleConfigureBounds(width: 0, height: 0)

        #expect(state.handleSurfaceConfigure(serial: 8).topLevel.bounds == nil)
    }

    @Test
    func partialZeroConfigureBoundsRecordsProtocolError() {
        let state = XDGConfigureState()
        state.handleConfigureBounds(width: 1_024, height: 0)

        #expect(throws: RuntimeError.invalidConfigureBounds(width: 1_024, height: 0)) {
            try state.throwPendingErrorIfAny()
        }
    }

    @Test
    func negativeConfigureBoundsRecordsProtocolError() {
        let state = XDGConfigureState()
        state.handleConfigureBounds(width: -1, height: 768)

        #expect(throws: RuntimeError.invalidConfigureBounds(width: -1, height: 768)) {
            try state.throwPendingErrorIfAny()
        }
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
