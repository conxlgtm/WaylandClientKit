import WaylandKeyboardInterpretation

extension WaylandKeyboardInterpretation.KeyboardInterpreterConfiguration {
    init(_ configuration: KeyboardInterpretationConfiguration) {
        self.init(compose: WaylandKeyboardInterpretation.KeyboardComposeMode(configuration.compose))
    }
}

extension WaylandKeyboardInterpretation.KeyboardComposeMode {
    init(_ configuration: KeyboardComposeConfiguration) {
        switch configuration {
        case .disabled:
            self = .disabled
        case .enabled(let locale, let policy):
            self = .enabled(
                locale: WaylandKeyboardInterpretation.KeyboardComposeLocale(locale),
                cancellationPolicy: WaylandKeyboardInterpretation.KeyboardComposeCancellationPolicy(
                    policy
                )
            )
        }
    }
}

extension WaylandKeyboardInterpretation.KeyboardComposeLocale {
    init(_ locale: KeyboardComposeLocale) {
        switch locale {
        case .processEnvironment:
            self = .processEnvironment
        case .identifier(let identifier):
            self = .identifier(
                WaylandKeyboardInterpretation.KeyboardComposeLocaleIdentifier(
                    unchecked: identifier.rawValue
                )
            )
        }
    }
}

extension WaylandKeyboardInterpretation.KeyboardComposeCancellationPolicy {
    init(_ policy: KeyboardComposeCancellationPolicy) {
        switch policy {
        case .passThroughCancellingKey:
            self = .passThroughCancellingKey
        case .swallowCancellingKey:
            self = .swallowCancellingKey
        }
    }
}
