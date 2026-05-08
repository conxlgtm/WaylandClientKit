import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowModelUnknownProtocolValueTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func unknownConfigureValuesPublishDiagnosticsOncePerRawValue() throws {
        var model = try modelWithDecorationReadyForConfigure()

        let firstEffects = try model.reduce(
            .configureReceived(
                configure(
                    width: 800,
                    height: 600,
                    serial: 7,
                    states: [XDGTopLevelState(rawValue: 99)],
                    wmCapabilities: [XDGWMCapability(rawValue: 77)],
                    decorationMode: .unknown(55)
                )
            )
        )
        let secondEffects = try model.reduce(
            .configureReceived(
                configure(
                    width: 800,
                    height: 600,
                    serial: 8,
                    states: [XDGTopLevelState(rawValue: 99)],
                    wmCapabilities: [XDGWMCapability(rawValue: 77)],
                    decorationMode: .unknown(55)
                )
            )
        )

        #expect(
            Array(firstEffects.prefix(3))
                == [
                    unknownProtocolDiagnostic(
                        field: .xdgTopLevelState,
                        rawValue: 99,
                        serial: 7
                    ),
                    unknownProtocolDiagnostic(
                        field: .xdgWMCapability,
                        rawValue: 77,
                        serial: 7
                    ),
                    unknownProtocolDiagnostic(
                        field: .xdgDecorationMode,
                        rawValue: 55,
                        serial: 7
                    ),
                ]
        )
        let hasRepeatedDiagnostic = secondEffects.contains { effect in
            guard case .publishDiagnostic = effect else {
                return false
            }

            return true
        }
        #expect(!hasRepeatedDiagnostic)
    }

    private func modelWithDecorationReadyForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        return model
    }

    private func unknownProtocolDiagnostic(
        field: UnknownWindowProtocolValueField,
        rawValue: UInt32,
        serial: UInt32
    ) -> WindowEffect {
        let diagnostic = UnknownWindowProtocolValueDiagnostic(
            field: field,
            rawValue: rawValue,
            configureSerial: serial
        )
        return .publishDiagnostic(
            WindowDiagnostic(
                windowID: windowID,
                payload: .unknownProtocolValue(diagnostic)
            )
        )
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
