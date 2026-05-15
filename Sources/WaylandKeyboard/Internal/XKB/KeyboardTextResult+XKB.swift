extension KeyboardTextResult {
    package static func xkbKey(
        _ text: String?,
        resultKeysym: KeyboardKeysym?,
        resultKeysymName: String?
    ) -> Self {
        guard let text else { return .none }

        return .committed(
            KeyboardTextCommit(
                string: text,
                source: .xkbKey,
                resultKeysym: resultKeysym,
                resultKeysymName: resultKeysymName
            )
        )
    }
}
