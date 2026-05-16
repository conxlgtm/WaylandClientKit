import Testing

@testable import WaylandGraphicsPreview

@Suite
struct GBMBufferPoolStateTests {
    @Test
    func leasesAvailableSlotsInStableOrder() throws {
        var state = GBMBufferPoolState()
        try state.insertAvailableSlot(try GBMBufferPoolSlotID(2))
        try state.insertAvailableSlot(try GBMBufferPoolSlotID(1))

        let first = try state.leaseNextAvailableSlot()
        let second = try state.leaseNextAvailableSlot()

        #expect(first == (try GBMBufferPoolSlotID(1)))
        #expect(second == (try GBMBufferPoolSlotID(2)))
        #expect(try state.lifecycle(for: first) == .leased)
        #expect(try state.lifecycle(for: second) == .leased)
    }

    @Test
    func negativeSlotIDIsRejected() {
        #expect(throws: GBMBufferPoolStateError.invalidSlotID(-1)) {
            _ = try GBMBufferPoolSlotID(-1)
        }
    }

    @Test
    func rejectedSlotIDDoesNotMutatePool() {
        var state = GBMBufferPoolState()

        #expect(throws: GBMBufferPoolStateError.invalidSlotID(-1)) {
            let slotID = try GBMBufferPoolSlotID(-1)
            try state.insertAvailableSlot(slotID)
        }

        #expect(throws: GBMBufferPoolStateError.noAvailableSlots) {
            _ = try state.leaseNextAvailableSlot()
        }
    }

    @Test
    func poolOnlyLeasesInsertedNonNegativeSlots() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(0)

        try state.insertAvailableSlot(slotID)

        #expect(try state.leaseNextAvailableSlot() == slotID)
        #expect(throws: GBMBufferPoolStateError.noAvailableSlots) {
            _ = try state.leaseNextAvailableSlot()
        }
    }

    @Test
    func submittedSlotIsNotAvailableUntilRelease() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(1)
        try state.insertAvailableSlot(slotID)

        let leasedSlotID = try state.leaseNextAvailableSlot()
        #expect(try state.lifecycle(for: leasedSlotID).isLeased)
        try state.markSubmitted(leasedSlotID, commitGeneration: 4)
        #expect(try state.lifecycle(for: leasedSlotID).submittedCommitGeneration == 4)
        #expect(state.submittedSlotIDs == [slotID])

        #expect(throws: GBMBufferPoolStateError.noAvailableSlots) {
            _ = try state.leaseNextAvailableSlot()
        }

        try state.markReleased(leasedSlotID)

        #expect(try state.lifecycle(for: leasedSlotID).isAvailable)
        #expect(try state.leaseNextAvailableSlot() == slotID)
    }

    @Test
    func cancelLeaseReturnsSlotToAvailable() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(1)
        try state.insertAvailableSlot(slotID)
        _ = try state.leaseNextAvailableSlot()

        try state.cancelLease(slotID)

        #expect(try state.lifecycle(for: slotID) == .available)
        #expect(try state.leaseNextAvailableSlot() == slotID)
    }

    @Test
    func duplicateSlotsAreRejected() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(1)
        let secondSlotID = try GBMBufferPoolSlotID(2)

        try state.insertAvailableSlot(slotID)
        try state.insertAvailableSlot(secondSlotID)

        #expect(state.slotIDs == [slotID, secondSlotID])

        #expect(throws: GBMBufferPoolStateError.duplicateSlot(slotID)) {
            try state.insertAvailableSlot(slotID)
        }
    }

    @Test
    func submitRequiresLeasedSlotAndPositiveGeneration() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(1)
        try state.insertAvailableSlot(slotID)

        #expect(throws: GBMBufferPoolStateError.invalidCommitGeneration(0)) {
            try state.markSubmitted(slotID, commitGeneration: 0)
        }
        #expect(
            throws: GBMBufferPoolStateError.slotNotLeased(slotID, actual: .available)
        ) {
            try state.markSubmitted(slotID, commitGeneration: 1)
        }
    }

    @Test
    func releaseRequiresSubmittedSlot() throws {
        var state = GBMBufferPoolState()
        let slotID = try GBMBufferPoolSlotID(1)
        try state.insertAvailableSlot(slotID)

        #expect(
            throws: GBMBufferPoolStateError.slotNotSubmitted(slotID, actual: .available)
        ) {
            try state.markReleased(slotID)
        }
    }
}
