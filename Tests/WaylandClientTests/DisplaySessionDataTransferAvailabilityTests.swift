import Testing

@testable import WaylandClient

@Suite
struct DisplaySessionDataTransferAvailabilityTests {
    @Test
    func optionalProcessingSkipsBeforeGlobalsAreBound() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .unbound,
            requirement: .optional
        )

        #expect(decision == .skip)
    }

    @Test
    func clipboardProcessingBindsGlobalsBeforeAnyWindow() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .unbound,
            requirement: .requiresDataDeviceManager
        )

        #expect(decision == .bindRequiredGlobals)
    }

    @Test
    func optionalProcessingSkipsWhenDataDeviceManagerIsMissing() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .boundWithoutDataDeviceManager,
            requirement: .optional
        )

        #expect(decision == .skip)
    }

    @Test
    func clipboardProcessingThrowsUnavailableWhenDataDeviceManagerIsMissing() {
        #expect(throws: DataTransferError.unavailable) {
            _ = try DisplaySession.dataTransferGlobalProcessingDecision(
                state: .boundWithoutDataDeviceManager,
                requirement: .requiresDataDeviceManager
            )
        }
    }

    @Test
    func processingSynchronizesSeatsWhenDataDeviceManagerIsAvailable() throws {
        let optionalDecision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .boundWithDataDeviceManager,
            requirement: .optional
        )
        let requiredDecision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .boundWithDataDeviceManager,
            requirement: .requiresDataDeviceManager
        )

        #expect(optionalDecision == .synchronizeSeats)
        #expect(requiredDecision == .synchronizeSeats)
    }
}
