import WaylandKeyboard

extension WaylandKeyboard.KeyboardInterpreterConfiguration {
    init(_ configuration: KeyboardInterpretationConfiguration) {
        self.init(compose: WaylandKeyboard.KeyboardComposeMode(configuration.compose))
    }
}

extension WaylandKeyboard.KeyboardComposeMode {
    init(_ configuration: KeyboardComposeConfiguration) {
        switch configuration {
        case .disabled:
            self = .disabled
        case .enabled(let locale, let policy):
            self = .enabled(
                locale: WaylandKeyboard.KeyboardComposeLocale(locale),
                cancellationPolicy: WaylandKeyboard.KeyboardComposeCancellationPolicy(
                    policy
                )
            )
        }
    }
}

extension WaylandKeyboard.KeyboardComposeLocale {
    init(_ locale: KeyboardComposeLocale) {
        switch locale {
        case .processEnvironment:
            self = .processEnvironment
        case .identifier(let identifier):
            self = .identifier(
                WaylandKeyboard.KeyboardComposeLocaleIdentifier(
                    unchecked: identifier.rawValue
                )
            )
        }
    }
}

extension WaylandKeyboard.KeyboardComposeCancellationPolicy {
    init(_ policy: KeyboardComposeCancellationPolicy) {
        switch policy {
        case .passThroughCancellingKey:
            self = .passThroughCancellingKey
        case .swallowCancellingKey:
            self = .swallowCancellingKey
        }
    }
}
