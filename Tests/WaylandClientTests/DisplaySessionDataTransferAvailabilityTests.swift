import Testing

@testable import WaylandClient

@Suite
struct DisplaySessionDataTransferAvailabilityTests {
    @Test
    func optionalProcessingSkipsBeforeGlobalsAreBound() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .unbound,
            requiresDataDeviceManager: false
        )

        #expect(decision == .skip)
    }

    @Test
    func clipboardProcessingBindsGlobalsBeforeAnyWindow() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .unbound,
            requiresDataDeviceManager: true
        )

        #expect(decision == .bindRequiredGlobals)
    }

    @Test
    func optionalProcessingSkipsWhenDataDeviceManagerIsMissing() throws {
        let decision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .bound(hasDataDeviceManager: false),
            requiresDataDeviceManager: false
        )

        #expect(decision == .skip)
    }

    @Test
    func clipboardProcessingThrowsUnavailableWhenDataDeviceManagerIsMissing() {
        #expect(throws: DataTransferError.unavailable) {
            _ = try DisplaySession.dataTransferGlobalProcessingDecision(
                state: .bound(hasDataDeviceManager: false),
                requiresDataDeviceManager: true
            )
        }
    }

    @Test
    func processingSynchronizesSeatsWhenDataDeviceManagerIsAvailable() throws {
        let optionalDecision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .bound(hasDataDeviceManager: true),
            requiresDataDeviceManager: false
        )
        let requiredDecision = try DisplaySession.dataTransferGlobalProcessingDecision(
            state: .bound(hasDataDeviceManager: true),
            requiresDataDeviceManager: true
        )

        #expect(optionalDecision == .synchronizeSeats)
        #expect(requiredDecision == .synchronizeSeats)
    }
}
