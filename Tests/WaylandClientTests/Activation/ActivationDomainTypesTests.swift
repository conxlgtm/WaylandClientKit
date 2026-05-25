import Testing

@testable import WaylandClient

@Suite
struct ActivationDomainTypesTests {
    @Test
    func activationTokenRejectsEmptyAndNULValues() {
        #expect(throws: ActivationError.invalidToken) {
            _ = try ActivationToken("")
        }

        #expect(throws: ActivationError.invalidToken) {
            _ = try ActivationToken("abc\0def")
        }
    }

    @Test
    func activationTokenPreservesOpaqueValue() throws {
        let token = try ActivationToken("opaque-token")

        #expect(token.value == "opaque-token")
        #expect(token.description == "opaque-token")
    }

    @Test
    func activationErrorDescriptionsAreStable() {
        #expect(ActivationError.unavailable.description.contains("not available"))
        #expect(ActivationError.tokenRequestTimedOut.description.contains("timed out"))
        #expect(ActivationError.displayClosed.description.contains("closed"))
    }
}
