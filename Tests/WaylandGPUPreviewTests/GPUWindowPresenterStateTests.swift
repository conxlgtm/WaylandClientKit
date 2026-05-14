import Testing

@testable import WaylandGPUPreview
@testable import WaylandGraphicsPreview

@Suite
struct GPUWindowPresenterStateTests {
    @Test
    func leaseSubmitReleaseReturnsSlotToAvailable() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(lease)
        try state.markReleased(slotID)

        #expect(lease == GPUWindowPresentationLease(slotID: slotID, generation: 1))
        #expect(try state.lifecycle(for: slotID) == .available)
    }

    @Test
    func failedPresentationCanCancelLease() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.cancelLease(lease)

        #expect(try state.lifecycle(for: slotID) == .available)
    }

    @Test
    func generationAdvancesForEachLease() throws {
        var state = GPUWindowPresenterState()
        try state.installSlot(try GBMBufferPoolSlotID(0))
        try state.installSlot(try GBMBufferPoolSlotID(1))

        let first = try state.leaseNext()
        try state.markSubmitted(first)
        let second = try state.leaseNext()

        #expect(first.generation == 1)
        #expect(second.generation == 2)
    }
}
