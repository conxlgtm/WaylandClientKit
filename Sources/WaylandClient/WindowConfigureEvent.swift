import WaylandRaw

package struct WindowConfigureEvent: Equatable, Sendable {
    let configuration: ResolvedWindowConfiguration
    let unknownValues: [UnknownWindowProtocolValueDiagnostic]

    var serial: UInt32 {
        configuration.serial
    }

    init(
        sequence: XDGConfigureSequence,
        previousSize: PositiveLogicalSize?,
        fallbackSize: PositiveLogicalSize
    ) throws {
        configuration = try ResolvedWindowConfiguration(
            sequence: sequence,
            previousSize: previousSize,
            fallbackSize: fallbackSize
        )
        unknownValues = Self.unknownValues(in: sequence)
    }

    private static func unknownValues(
        in sequence: XDGConfigureSequence
    ) -> [UnknownWindowProtocolValueDiagnostic] {
        stateUnknownValues(in: sequence)
            + capabilityUnknownValues(in: sequence)
            + decorationUnknownValues(in: sequence)
    }

    private static func stateUnknownValues(
        in sequence: XDGConfigureSequence
    ) -> [UnknownWindowProtocolValueDiagnostic] {
        sequence.topLevel.states.compactMap { state in
            guard case .unknown(let rawValue) = WindowStateToken(state) else {
                return nil
            }

            return diagnostic(
                field: .xdgTopLevelState,
                rawValue: rawValue,
                serial: sequence.serial
            )
        }
    }

    private static func capabilityUnknownValues(
        in sequence: XDGConfigureSequence
    ) -> [UnknownWindowProtocolValueDiagnostic] {
        sequence.topLevel.wmCapabilities.compactMap { capability in
            guard case .unknown(let rawValue) = WindowManagerCapability(capability) else {
                return nil
            }

            return diagnostic(
                field: .xdgWMCapability,
                rawValue: rawValue,
                serial: sequence.serial
            )
        }
    }

    private static func decorationUnknownValues(
        in sequence: XDGConfigureSequence
    ) -> [UnknownWindowProtocolValueDiagnostic] {
        guard case .some(.unknown(let rawValue)) = sequence.decorationMode else {
            return []
        }

        return [
            diagnostic(
                field: .xdgDecorationMode,
                rawValue: rawValue,
                serial: sequence.serial
            )
        ]
    }

    private static func diagnostic(
        field: UnknownWindowProtocolValueField,
        rawValue: UInt32,
        serial: UInt32
    ) -> UnknownWindowProtocolValueDiagnostic {
        UnknownWindowProtocolValueDiagnostic(
            field: field,
            rawValue: rawValue,
            configureSerial: serial
        )
    }
}
