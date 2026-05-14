import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

package struct GPUWindowPresentationLease: Equatable, Sendable {
    package let slotID: GBMBufferPoolSlotID
}

package struct GPUWindowPresentedFrame: Equatable, Sendable {
    package let slotID: GBMBufferPoolSlotID
    package let generation: UInt64
    package let commitPlan: SurfaceCommitPlan
}

package enum GPUWindowPresenterError: Error, CustomStringConvertible {
    case pool(GBMBufferPoolStateError)
    case missingBuffer(GBMBufferPoolSlotID)
    case releaseFailure(GBMBufferPoolStateError)
    case window(any Error)

    package var description: String {
        switch self {
        case .pool(let error):
            error.description
        case .missingBuffer(let slotID):
            "missing GPU buffer for slot \(slotID.rawValue)"
        case .releaseFailure(let error):
            "GPU buffer release failed: \(error.description)"
        case .window(let error):
            "GPU window presentation failed: \(String(describing: error))"
        }
    }
}

package struct GPUWindowPresenterState: Equatable, Sendable {
    private var poolState = GBMBufferPoolState()

    package init() {
        // Slots are installed as dmabuf wl_buffers become available.
    }

    package func lifecycle(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) -> GBMBufferPoolSlotLifecycle {
        try poolState.lifecycle(for: slotID)
    }

    package mutating func installSlot(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        try poolState.insertAvailableSlot(slotID)
    }

    package mutating func leaseNext()
        throws(GBMBufferPoolStateError) -> GPUWindowPresentationLease
    {
        let slotID = try poolState.leaseNextAvailableSlot()
        return GPUWindowPresentationLease(slotID: slotID)
    }

    package mutating func markSubmitted(
        _ lease: GPUWindowPresentationLease,
        generation: UInt64
    ) throws(GBMBufferPoolStateError) {
        try poolState.markSubmitted(
            lease.slotID,
            commitGeneration: generation
        )
    }

    package mutating func cancelLease(
        _ lease: GPUWindowPresentationLease
    ) throws(GBMBufferPoolStateError) {
        try poolState.cancelLease(lease.slotID)
    }

    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        try poolState.markReleased(slotID)
    }
}

@safe
package final class GPUWindowPresenter {
    private var state = GPUWindowPresenterState()
    private var buffers: [GBMBufferPoolSlotID: RawLinuxDmabufBuffer] = [:]
    private var releaseFailures: [GBMBufferPoolStateError] = []

    package init() {
        // Buffers are installed after dmabuf import completes.
    }

    package func installBuffer(
        _ buffer: RawLinuxDmabufBuffer,
        slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterError) {
        do {
            try state.installSlot(slotID)
        } catch {
            throw GPUWindowPresenterError.pool(error)
        }

        buffers[slotID] = buffer
        buffer.setReleaseObserver { [weak self] in
            self?.recordRelease(slotID)
        }
    }

    package func presentNext(
        on window: TopLevelWindow
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        if let releaseFailure = releaseFailures.first {
            throw GPUWindowPresenterError.releaseFailure(releaseFailure)
        }

        let lease: GPUWindowPresentationLease
        do {
            lease = try state.leaseNext()
        } catch {
            throw GPUWindowPresenterError.pool(error)
        }

        guard let buffer = buffers[lease.slotID] else {
            try cancelLeaseAfterFailedPresentation(lease)
            throw GPUWindowPresenterError.missingBuffer(lease.slotID)
        }

        do {
            let presentation = try window.presentPreviewBufferOnOwnerThread(
                buffer.surfaceBuffer
            )
            try state.markSubmitted(lease, generation: presentation.generation)
            return GPUWindowPresentedFrame(
                slotID: lease.slotID,
                generation: presentation.generation,
                commitPlan: presentation.commitPlan
            )
        } catch let error as GBMBufferPoolStateError {
            try cancelLeaseAfterFailedPresentation(lease)
            throw GPUWindowPresenterError.pool(error)
        } catch {
            try cancelLeaseAfterFailedPresentation(lease)
            throw GPUWindowPresenterError.window(error)
        }
    }

    private func cancelLeaseAfterFailedPresentation(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterError) {
        do {
            try state.cancelLease(lease)
        } catch {
            throw GPUWindowPresenterError.pool(error)
        }
    }

    private func recordRelease(_ slotID: GBMBufferPoolSlotID) {
        do {
            try state.markReleased(slotID)
        } catch {
            releaseFailures.append(error)
        }
    }
}
