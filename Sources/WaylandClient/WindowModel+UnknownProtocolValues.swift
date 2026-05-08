import WaylandRaw

extension WindowModel {
    mutating func unknownProtocolValueEffects(
        for sequence: XDGConfigureSequence
    ) -> [WindowEffect] {
        var effects: [WindowEffect] = []
        for state in sequence.topLevel.states {
            if case .unknown(let rawValue) = WindowStateToken(state) {
                appendUnknownProtocolValueEffect(
                    field: .xdgTopLevelState,
                    rawValue: rawValue,
                    configureSerial: sequence.serial,
                    to: &effects
                )
            }
        }
        for capability in sequence.topLevel.wmCapabilities {
            if case .unknown(let rawValue) = WindowManagerCapability(capability) {
                appendUnknownProtocolValueEffect(
                    field: .xdgWMCapability,
                    rawValue: rawValue,
                    configureSerial: sequence.serial,
                    to: &effects
                )
            }
        }
        if case .some(.unknown(let rawValue)) = sequence.decorationMode {
            appendUnknownProtocolValueEffect(
                field: .xdgDecorationMode,
                rawValue: rawValue,
                configureSerial: sequence.serial,
                to: &effects
            )
        }

        return effects
    }

    private mutating func appendUnknownProtocolValueEffect(
        field: UnknownWindowProtocolValueField,
        rawValue: UInt32,
        configureSerial: UInt32,
        to effects: inout [WindowEffect]
    ) {
        let key = ReportedUnknownWindowProtocolValue(field: field, rawValue: rawValue)
        guard reportedUnknownProtocolValues.insert(key).inserted else {
            return
        }

        let diagnostic = UnknownWindowProtocolValueDiagnostic(
            field: field,
            rawValue: rawValue,
            configureSerial: configureSerial
        )
        effects.append(
            .publishDiagnostic(
                WindowDiagnostic(
                    windowID: id,
                    operation: .unknownProtocolValue(field),
                    message: diagnostic.description
                )
            )
        )
    }
}
