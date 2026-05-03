extension WindowModel {
    package var decorationMode: WindowDecorationMode {
        decoration.currentMode
    }

    package mutating func reduceDecorationUnavailable(
        _ reason: DecorationUnavailableReason?
    ) throws -> [WindowEffect] {
        if decoration == .unavailable(reason: reason) {
            return []
        }

        guard canStartDecorationNegotiation else {
            throw invalidDecorationTransition(event: "decorationUnavailable")
        }

        decoration = .unavailable(reason: reason)
        return []
    }

    package mutating func reduceDecorationObjectCreated(
        _ preference: WindowDecorationPreference
    ) throws -> [WindowEffect] {
        guard canStartDecorationNegotiation else {
            throw invalidDecorationTransition(event: "decorationObjectCreated")
        }

        decoration = .objectCreated(preference: preference)
        return []
    }

    package mutating func reduceDecorationPreferenceRequested(
        _ preference: WindowDecorationPreference
    ) throws -> [WindowEffect] {
        switch decoration {
        case .objectCreated(let createdPreference) where createdPreference == preference:
            decoration = .requested(preference)
        case .requested(let requestedPreference) where requestedPreference == preference:
            return []
        case .objectCreated, .requested, .unavailable, .configured:
            throw invalidDecorationTransition(event: "decorationPreferenceRequested")
        }

        return []
    }

    package mutating func reduceDecorationConfigured(
        _ mode: WindowDecorationMode
    ) throws -> [WindowEffect] {
        switch decoration {
        case .requested, .configured:
            decoration = .configured(mode)
        case .unavailable, .objectCreated:
            throw invalidDecorationTransition(event: "decorationConfigured")
        }

        return []
    }

    private var canStartDecorationNegotiation: Bool {
        guard case .created = lifecycle else {
            return false
        }

        guard case .unavailable(reason: nil) = decoration else {
            return false
        }

        return true
    }

    private func invalidDecorationTransition(event: String) -> ClientError {
        ClientError.window(
            id,
            .invalidLifecycleTransition(
                .invalidTransition(
                    from: "\(lifecycle.description) decoration=\(decoration)",
                    event: event
                )
            )
        )
    }
}
