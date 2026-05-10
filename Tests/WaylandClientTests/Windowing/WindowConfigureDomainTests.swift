import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowConfigureDomainTests {
    @Test
    func knownXDGStatesMapToWindowStateTokens() throws {
        let configuration = try ResolvedWindowConfiguration(
            sequence: configure(
                width: 640,
                height: 480,
                states: [.activated, .fullscreen, .tiledLeft, .constrainedBottom],
                wmCapabilities: [.windowMenu, .maximize]
            ),
            previousSize: nil,
            fallbackSize: .default
        )

        #expect(
            configuration.states
                == [
                    .activated,
                    .fullscreen,
                    .tiled(.left),
                    .constrained(.bottom),
                ]
        )
        #expect(configuration.wmCapabilities == [.windowMenu, .maximize])
    }

    @Test
    func unknownXDGStateAndCapabilitySurviveConfigureResolution() throws {
        let configuration = try ResolvedWindowConfiguration(
            sequence: configure(
                width: 640,
                height: 480,
                states: [XDGTopLevelState(rawValue: 99)],
                wmCapabilities: [XDGWMCapability(rawValue: 77)],
                decorationMode: .unknown(55)
            ),
            previousSize: nil,
            fallbackSize: .default
        )

        #expect(configuration.states == [.unknown(99)])
        #expect(configuration.wmCapabilities == [.unknown(77)])
        #expect(configuration.decorationMode == .unknown(55))
        #expect(configuration.states.map(\.rawValue) == [99])
        #expect(configuration.wmCapabilities.map(\.rawValue) == [77])
    }

    @Test
    func presentationSummaryUsesDomainWindowTokens() throws {
        let configuration = try ResolvedWindowConfiguration(
            sequence: configure(
                width: 640,
                height: 480,
                states: [.activated, XDGTopLevelState(rawValue: 99)],
                wmCapabilities: [.fullscreen, XDGWMCapability(rawValue: 77)]
            ),
            previousSize: nil,
            fallbackSize: .default
        )
        let request = PresentationRequest(generation: 3, configuration: configuration)

        #expect(request.summary.states == [.activated, .unknown(99)])
        #expect(request.summary.wmCapabilities == [.fullscreen, .unknown(77)])
        #expect(request.summary.states.map(\.rawValue) == [4, 99])
        #expect(request.summary.wmCapabilities.map(\.rawValue) == [3, 77])
    }

    @Test
    func stateSnapshotCopiesResolvedConfigureState() throws {
        let configuration = try ResolvedWindowConfiguration(
            sequence: configure(
                width: 640,
                height: 480,
                serial: 42,
                states: [.activated],
                wmCapabilities: [.maximize],
                decorationMode: .serverSide
            ),
            previousSize: nil,
            fallbackSize: .default
        )

        let snapshot = WindowStateSnapshot(
            configuration,
            outputIDs: [OutputID(rawValue: 2), OutputID(rawValue: 1)]
        )
        let expectedSize = try PositiveLogicalSize(width: 640, height: 480)

        #expect(snapshot.configureSerial == 42)
        #expect(snapshot.size == expectedSize)
        #expect(snapshot.states == [.activated])
        #expect(snapshot.managerCapabilities == [.maximize])
        #expect(snapshot.decorationMode == .serverSide)
        #expect(snapshot.outputs == [OutputID(rawValue: 2), OutputID(rawValue: 1)])
    }

    @Test
    func resizeEdgesMapToXDGProtocolValues() {
        #expect(WindowResizeEdge.top.rawXDGResizeEdge.rawValue == 1)
        #expect(WindowResizeEdge.bottom.rawXDGResizeEdge.rawValue == 2)
        #expect(WindowResizeEdge.left.rawXDGResizeEdge.rawValue == 4)
        #expect(WindowResizeEdge.topLeft.rawXDGResizeEdge.rawValue == 5)
        #expect(WindowResizeEdge.bottomLeft.rawXDGResizeEdge.rawValue == 6)
        #expect(WindowResizeEdge.right.rawXDGResizeEdge.rawValue == 8)
        #expect(WindowResizeEdge.topRight.rawXDGResizeEdge.rawValue == 9)
        #expect(WindowResizeEdge.bottomRight.rawXDGResizeEdge.rawValue == 10)
    }

    @Test
    func normalizeConfigureSizeIsIdempotentForProtocolSamples() throws {
        let samples: [(Int32, Int32)] = [
            (0, 0),
            (0, 480),
            (640, 0),
            (1, 1),
            (1_920, 1_080),
        ]

        for (width, height) in samples {
            let first = try TopLevelSizeSuggestion.normalize(width: width, height: height)
            let second = try TopLevelSizeSuggestion.normalize(
                width: first.width.suggestedValue?.rawValue ?? 0,
                height: first.height.suggestedValue?.rawValue ?? 0
            )

            #expect(second == first)
        }
    }

    private func configure(
        width: Int32,
        height: Int32,
        serial: UInt32 = 1,
        states: [XDGTopLevelState] = [],
        wmCapabilities: [XDGWMCapability] = [],
        decorationMode: RawDecorationMode? = nil
    ) -> XDGConfigureSequence {
        XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: TopLevelSize(width: width, height: height),
                states: states,
                wmCapabilities: wmCapabilities
            ),
            decorationMode: decorationMode
        )
    }
}
