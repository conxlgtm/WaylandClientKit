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
    private let boundSnapshot: DataTransferGlobalSnapshot
    private(set) var bindRequiredGlobalsCount = 0

    init(
        currentSnapshot: DataTransferGlobalSnapshot?,
        boundSnapshot snapshotAfterBinding: DataTransferGlobalSnapshot =
            DataTransferGlobalSnapshot(
                bindingState: .boundWithDataDeviceManager,
                seatIDs: []
            )
    ) {
        currentDataTransferGlobalSnapshot = currentSnapshot
        boundSnapshot = snapshotAfterBinding
    }

    func bindRequiredDataTransferGlobals() throws -> DataTransferGlobalSnapshot {
        bindRequiredGlobalsCount += 1
        currentDataTransferGlobalSnapshot = boundSnapshot
        return boundSnapshot
    }
}
