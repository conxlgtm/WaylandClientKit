import Testing
import WaylandKeyboard

@testable import WaylandClient

@Suite
struct KeyboardInterpretationConfigurationTests {
    @Test
    func publicComposeDisabledMapsToInternalDisabled() {
        let mapped = WaylandKeyboard.KeyboardInterpreterConfiguration(
            KeyboardInterpretationConfiguration(compose: .disabled)
        )

        #expect(mapped.compose == .disabled)
    }

    @Test
    func publicComposeCancellationPolicyMapsToInternalPolicy() throws {
        let locale = try WaylandClient.KeyboardComposeLocaleIdentifier("sv_SE.UTF-8")
        let mapped = WaylandKeyboard.KeyboardInterpreterConfiguration(
            KeyboardInterpretationConfiguration(
                compose: .enabled(
                    locale: .identifier(locale),
                    cancellationPolicy: .swallowCancellingKey
                )
            )
        )

        #expect(
            mapped.compose
                == .enabled(
                    locale: .identifier(
                        WaylandKeyboard.KeyboardComposeLocaleIdentifier(
                            unchecked: "sv_SE.UTF-8"
                        )
                    ),
                    cancellationPolicy: .swallowCancellingKey
                ))
    }

    @Test
    func displaySessionUsesKeyboardInterpretationConfiguration() {
        let mapped = DisplaySession.keyboardInterpreterConfiguration(
            for: KeyboardInterpretationConfiguration(compose: .disabled)
        )

        #expect(mapped.compose == .disabled)
    }

    @Test
    func emptyComposeLocaleIdentifierIsRejected() {
        #expect(throws: WaylandClient.KeyboardComposeLocaleError.emptyIdentifier) {
            try WaylandClient.KeyboardComposeLocaleIdentifier("")
        }
    }

    @Test
    func whitespaceComposeLocaleIdentifierIsRejected() {
        #expect(throws: WaylandClient.KeyboardComposeLocaleError.emptyIdentifier) {
            try WaylandClient.KeyboardComposeLocaleIdentifier("  \n\t")
        }
    }
}
