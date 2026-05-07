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
                wmCapabilities: [XDGWMCapability(rawValue: 77)]
            ),
            previousSize: nil,
            fallbackSize: .default
        )

        #expect(configuration.states == [.unknown(99)])
        #expect(configuration.wmCapabilities == [.unknown(77)])
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
