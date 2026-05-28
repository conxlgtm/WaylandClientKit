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
    func activationAppIDRejectsEmptyAndNULValues() {
        #expect(throws: ActivationError.invalidAppID) {
            _ = try ActivationAppID("")
        }

        #expect(throws: ActivationError.invalidAppID) {
            _ = try ActivationAppID("abc\0def")
        }
    }

    @Test
    func activationRequestStoresValidatedAppIDAndSerialContext() throws {
        let appID = try ActivationAppID("org.swiftwayland.Test")
        let serialContext = ActivationSerialContext(
            seatID: SeatID(rawValue: 1),
            serial: InputSerial(rawValue: 2)
        )
        let request = ActivationTokenRequest(
            appID: appID,
            serialContext: serialContext
        )

        #expect(request.appID == appID)
        #expect(request.serialContext == serialContext)
    }

    @Test
    func activationRequestRejectsInvalidAppIDAtConstruction() {
        #expect(throws: ActivationError.invalidAppID) {
            _ = try ActivationTokenRequest(validatingAppID: "")
        }

        #expect(throws: ActivationError.invalidAppID) {
            _ = try ActivationTokenRequest(validatingAppID: "bad\0id")
        }
    }

    @Test
    func activationErrorDescriptionsAreStable() {
        #expect(ActivationError.unavailable.description.contains("not available"))
        #expect(ActivationError.tokenRequestTimedOut.description.contains("timed out"))
        #expect(ActivationError.cancelled.description.contains("cancelled"))
        #expect(ActivationError.displayClosed.description.contains("closed"))
    }
}
