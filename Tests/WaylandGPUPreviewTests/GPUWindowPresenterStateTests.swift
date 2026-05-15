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
        try state.markSubmitted(lease, generation: 1)
        try state.markReleased(slotID)

        #expect(lease == GPUWindowPresentationLease(slotID: slotID))
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
    func submissionUsesWindowCommitGeneration() throws {
        var state = GPUWindowPresenterState()
        let slotID = try GBMBufferPoolSlotID(0)
        try state.installSlot(slotID)

        let lease = try state.leaseNext()
        try state.markSubmitted(lease, generation: 42)

        #expect(try state.lifecycle(for: slotID) == .submitted(commitGeneration: 42))
    }
}
