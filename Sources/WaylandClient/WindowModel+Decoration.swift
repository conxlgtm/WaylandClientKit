extension WindowModel {
    package var decorationMode: WindowDecorationMode {
        decoration.currentMode
    }

    package mutating func reduceDecorationUnavailable(
        _ reason: DecorationUnavailableReason?
    ) -> [WindowEffect] {
        decoration = .unavailable(reason: reason)
        return []
    }

    package mutating func reduceDecorationObjectCreated(
        _ preference: WindowDecorationPreference
    ) -> [WindowEffect] {
        decoration = .objectCreated(preference: preference)
        return []
    }

    package mutating func reduceDecorationPreferenceRequested(
        _ preference: WindowDecorationPreference
    ) -> [WindowEffect] {
        decoration = .requested(preference)
        return []
    }
}
