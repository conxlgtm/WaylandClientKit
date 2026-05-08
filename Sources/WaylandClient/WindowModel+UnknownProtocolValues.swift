extension WindowModel {
    mutating func unknownProtocolValueEffects(
        for diagnostics: [UnknownWindowProtocolValueDiagnostic]
    ) -> [WindowEffect] {
        var effects: [WindowEffect] = []
        for diagnostic in diagnostics {
            appendUnknownProtocolValueEffect(
                diagnostic,
                to: &effects
            )
        }

        return effects
    }

    private mutating func appendUnknownProtocolValueEffect(
        _ diagnostic: UnknownWindowProtocolValueDiagnostic,
        to effects: inout [WindowEffect]
    ) {
        let key = ReportedUnknownWindowProtocolValue(
            field: diagnostic.field,
            rawValue: diagnostic.rawValue
        )
        guard reportedUnknownProtocolValues.insert(key).inserted else {
            return
        }

        effects.append(
            .publishDiagnostic(
                WindowDiagnostic(
                    windowID: id,
                    payload: .unknownProtocolValue(diagnostic)
                )
            )
        )
    }
}
