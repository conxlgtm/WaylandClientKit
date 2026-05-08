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

    @Test
    func primarySelectionProcessingBindsGlobalsBeforeAnyWindow() throws {
        let decision = try DisplaySession.primarySelectionGlobalProcessingDecision(
            state: .unbound,
            requirement: .requiresPrimarySelectionDeviceManager
        )

        #expect(decision == .bindRequiredGlobals)
    }

    @Test
    func optionalPrimarySelectionProcessingSkipsWhenManagerIsMissing() throws {
        let decision = try DisplaySession.primarySelectionGlobalProcessingDecision(
            state: .boundWithoutPrimarySelectionDeviceManager,
            requirement: .optional
        )

        #expect(decision == .skip)
    }

    @Test
    func primarySelectionProcessingThrowsUnavailableWhenManagerIsMissing() {
        #expect(throws: DataTransferError.unavailable) {
            _ = try DisplaySession.primarySelectionGlobalProcessingDecision(
                state: .boundWithoutPrimarySelectionDeviceManager,
                requirement: .requiresPrimarySelectionDeviceManager
            )
        }
    }

    @Test
    func primarySelectionProcessingSynchronizesSeatsWhenManagerIsAvailable() throws {
        let seatIDs = [SeatID(rawValue: 7), SeatID(rawValue: 11)]
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: nil,
            currentPrimarySelectionSnapshot: nil,
            boundPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithPrimarySelectionDeviceManager,
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

    @Test
    func setClipboardBeforeWindowBindsGlobalsAndSynchronizesSeats() throws {
        let seatIDs = [SeatID(rawValue: 7), SeatID(rawValue: 11)]
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: nil,
            boundSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithDataDeviceManager,
                seatIDs: seatIDs
            )
        )
        var synchronizedSeatIDs: [SeatID] = []

        let outcome = try DisplaySession.processDataTransferGlobals(
            requirement: .requiresDataDeviceManager,
            provider: provider
        ) { seatIDs in
            synchronizedSeatIDs = seatIDs
        }

        #expect(outcome == .synchronized)
        #expect(provider.bindRequiredGlobalsCount == 1)
        #expect(synchronizedSeatIDs == seatIDs)
    }

    @Test
    func clipboardOfferWithoutDataDeviceManagerThrowsUnavailable() {
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithoutDataDeviceManager,
                seatIDs: [SeatID(rawValue: 7)]
            )
        )
        var synchronizedSeatIDs: [SeatID] = []

        #expect(throws: DataTransferError.unavailable) {
            try DisplaySession.processDataTransferGlobals(
                requirement: .requiresDataDeviceManager,
                provider: provider
            ) { seatIDs in
                synchronizedSeatIDs = seatIDs
            }
        }

        #expect(provider.bindRequiredGlobalsCount == 0)
        #expect(synchronizedSeatIDs.isEmpty)
    }

    @Test
    func receiveClipboardOfferWithoutDataDeviceManagerThrowsUnavailable() {
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: nil,
            boundSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithoutDataDeviceManager,
                seatIDs: [SeatID(rawValue: 9)]
            )
        )
        var synchronizedSeatIDs: [SeatID] = []

        #expect(throws: DataTransferError.unavailable) {
            try DisplaySession.processDataTransferGlobals(
                requirement: .requiresDataDeviceManager,
                provider: provider
            ) { seatIDs in
                synchronizedSeatIDs = seatIDs
            }
        }

        #expect(provider.bindRequiredGlobalsCount == 1)
        #expect(synchronizedSeatIDs.isEmpty)
    }

    @Test
    func optionalInputProcessingSkipsUnboundGlobals() throws {
        let provider = RecordingDataTransferGlobalProvider(currentSnapshot: nil)
        var synchronizedSeatIDs: [SeatID] = []

        let outcome = try DisplaySession.processDataTransferGlobals(
            requirement: .optional,
            provider: provider
        ) { seatIDs in
            synchronizedSeatIDs = seatIDs
        }

        #expect(outcome == .skipped)
        #expect(provider.bindRequiredGlobalsCount == 0)
        #expect(synchronizedSeatIDs.isEmpty)
    }

    @Test
    func optionalProcessingDoesNotSubmitSourceWritesWhenGlobalsAreUnbound() throws {
        let provider = RecordingDataTransferGlobalProvider(currentSnapshot: nil)
        var synchronizedSeatIDs: [SeatID] = []
        var sourceWriteSubmitCount = 0

        try DisplaySession.processDataTransferGlobalEffects(
            requirement: .optional,
            provider: provider,
            synchronizeSeats: { seatIDs in
                synchronizedSeatIDs = seatIDs
            },
            submitSourceWrites: {
                sourceWriteSubmitCount += 1
            }
        )

        #expect(provider.bindRequiredGlobalsCount == 0)
        #expect(synchronizedSeatIDs.isEmpty)
        #expect(sourceWriteSubmitCount == 0)
    }

    @Test
    func optionalProcessingDoesNotSubmitSourceWritesWhenDataDeviceManagerIsMissing() throws {
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithoutDataDeviceManager,
                seatIDs: [SeatID(rawValue: 7)]
            )
        )
        var synchronizedSeatIDs: [SeatID] = []
        var sourceWriteSubmitCount = 0

        try DisplaySession.processDataTransferGlobalEffects(
            requirement: .optional,
            provider: provider,
            synchronizeSeats: { seatIDs in
                synchronizedSeatIDs = seatIDs
            },
            submitSourceWrites: {
                sourceWriteSubmitCount += 1
            }
        )

        #expect(provider.bindRequiredGlobalsCount == 0)
        #expect(synchronizedSeatIDs.isEmpty)
        #expect(sourceWriteSubmitCount == 0)
    }

    @Test
    func requiredProcessingSubmitsSourceWritesAfterBindingAndSynchronizingSeats() throws {
        let seatIDs = [SeatID(rawValue: 3)]
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: nil,
            boundSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithDataDeviceManager,
                seatIDs: seatIDs
            )
        )
        var synchronizedSeatIDs: [SeatID] = []
        var sourceWriteSubmitCount = 0

        try DisplaySession.processDataTransferGlobalEffects(
            requirement: .requiresDataDeviceManager,
            provider: provider,
            synchronizeSeats: { seatIDs in
                synchronizedSeatIDs = seatIDs
            },
            submitSourceWrites: {
                sourceWriteSubmitCount += 1
            }
        )

        #expect(provider.bindRequiredGlobalsCount == 1)
        #expect(synchronizedSeatIDs == seatIDs)
        #expect(sourceWriteSubmitCount == 1)
    }

    @Test
    func requiredProcessingDoesNotSubmitSourceWritesWhenDataDeviceManagerIsMissing() {
        let provider = RecordingDataTransferGlobalProvider(
            currentSnapshot: nil,
            boundSnapshot: DataTransferGlobalSnapshot(
                bindingState: .boundWithoutDataDeviceManager,
                seatIDs: [SeatID(rawValue: 5)]
            )
        )
        var synchronizedSeatIDs: [SeatID] = []
        var sourceWriteSubmitCount = 0

        #expect(throws: DataTransferError.unavailable) {
            try DisplaySession.processDataTransferGlobalEffects(
                requirement: .requiresDataDeviceManager,
                provider: provider,
                synchronizeSeats: { seatIDs in
                    synchronizedSeatIDs = seatIDs
                },
                submitSourceWrites: {
                    sourceWriteSubmitCount += 1
                }
            )
        }

        #expect(provider.bindRequiredGlobalsCount == 1)
        #expect(synchronizedSeatIDs.isEmpty)
        #expect(sourceWriteSubmitCount == 0)
    }
}

private final class RecordingDataTransferGlobalProvider: DataTransferGlobalProviding {
    private(set) var currentDataTransferGlobalSnapshot: DataTransferGlobalSnapshot?
    private(set) var currentPrimarySelectionGlobalSnapshot: PrimarySelectionGlobalSnapshot?
    private let boundSnapshot: DataTransferGlobalSnapshot
    private let boundPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot
    private(set) var bindRequiredGlobalsCount = 0
    private(set) var bindRequiredPrimarySelectionGlobalsCount = 0

    init(
        currentSnapshot: DataTransferGlobalSnapshot?,
        currentPrimarySelectionSnapshot: PrimarySelectionGlobalSnapshot? = nil,
        boundSnapshot snapshotAfterBinding: DataTransferGlobalSnapshot =
            DataTransferGlobalSnapshot(
                bindingState: .boundWithDataDeviceManager,
                seatIDs: []
            ),
        boundPrimarySelectionSnapshot primarySelectionSnapshotAfterBinding:
            PrimarySelectionGlobalSnapshot =
            PrimarySelectionGlobalSnapshot(
                bindingState: .boundWithPrimarySelectionDeviceManager,
                seatIDs: []
            )
    ) {
        currentDataTransferGlobalSnapshot = currentSnapshot
        currentPrimarySelectionGlobalSnapshot = currentPrimarySelectionSnapshot
        boundSnapshot = snapshotAfterBinding
        boundPrimarySelectionSnapshot = primarySelectionSnapshotAfterBinding
    }

    func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot {
        bindRequiredGlobalsCount += 1
        currentDataTransferGlobalSnapshot = boundSnapshot
        return boundSnapshot
    }

    func bindRequiredPrimarySelectionGlobals() throws -> PrimarySelectionGlobalSnapshot {
        bindRequiredPrimarySelectionGlobalsCount += 1
        currentPrimarySelectionGlobalSnapshot = boundPrimarySelectionSnapshot
        return boundPrimarySelectionSnapshot
    }
}
