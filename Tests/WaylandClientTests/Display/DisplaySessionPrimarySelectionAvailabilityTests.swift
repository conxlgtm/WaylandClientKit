import Testing

@testable import WaylandClient

@Suite
struct PrimarySelectionAvailabilityTests {
    @Test
    func processingBindsGlobalsBeforeAnyWindow() throws {
        let decision = try DisplaySession.primarySelectionGlobalProcessingDecision(
            state: .unbound,
            requirement: .requiresPrimarySelectionDeviceManager
        )

        #expect(decision == .bindRequiredGlobals)
    }

    @Test
    func optionalProcessingSkipsWhenManagerIsMissing() throws {
        let decision = try DisplaySession.primarySelectionGlobalProcessingDecision(
            state: .boundWithoutPrimaryManager,
            requirement: .optional
        )

        #expect(decision == .skip)
    }

    @Test
    func processingThrowsUnavailableWhenManagerIsMissing() {
        #expect(throws: DataTransferError.unavailable) {
            _ = try DisplaySession.primarySelectionGlobalProcessingDecision(
                state: .boundWithoutPrimaryManager,
                requirement: .requiresPrimarySelectionDeviceManager
            )
        }
    }

    @Test
    func processingSynchronizesSeatsWhenManagerIsAvailable() throws {
        let seatIDs = [SeatID(rawValue: 7), SeatID(rawValue: 11)]
        let provider = RecordingPrimarySelectionGlobalProvider(
            currentPrimarySelectionSnapshot: nil,
            boundPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithPrimaryManager,
                seatIDs: seatIDs
            )
        )
        var synchronizedSeatIDs: [SeatID] = []

        let outcome = try DisplaySession.processPrimarySelectionGlobals(
            requirement: .requiresPrimarySelectionDeviceManager,
            provider: provider
        ) { seatIDs in
            synchronizedSeatIDs = seatIDs
        }

        #expect(outcome == .synchronized)
        #expect(provider.bindRequiredPrimarySelectionGlobalsCount == 1)
        #expect(synchronizedSeatIDs == seatIDs)
    }
}

private final class RecordingPrimarySelectionGlobalProvider: DataTransferGlobalProviding {
    var currentDataTransferGlobalSnapshot: DataTransferGlobalSnapshot?
    private(set) var currentPrimarySelectionGlobalSnapshot: PrimarySelectionGlobalSnapshot?
    private let boundPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot
    private(set) var bindRequiredPrimarySelectionGlobalsCount = 0

    init(
        currentPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot?,
        boundPrimarySelectionSnapshot primarySelectionSnapshotAfterBinding:
            PrimarySelectionGlobalSnapshot =
            PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithPrimaryManager,
                seatIDs: []
            )
    ) {
        currentDataTransferGlobalSnapshot = nil
        currentPrimarySelectionGlobalSnapshot = currentPrimarySelectionSnapshot
        boundPrimarySelectionSnapshot = primarySelectionSnapshotAfterBinding
    }

    func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot {
        throw DataTransferError.unavailable
    }

    func bindRequiredPrimarySelectionGlobals() throws -> PrimarySelectionGlobalSnapshot {
        bindRequiredPrimarySelectionGlobalsCount += 1
        currentPrimarySelectionGlobalSnapshot = boundPrimarySelectionSnapshot
        return boundPrimarySelectionSnapshot
    }
}
