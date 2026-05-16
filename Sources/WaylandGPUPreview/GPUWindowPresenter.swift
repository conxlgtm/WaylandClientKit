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

package enum GPUWindowPresenterRetireReason: Equatable, Sendable, CustomStringConvertible {
    case windowClosed

    package var description: String {
        switch self {
        case .windowClosed:
            "window closed"
        }
    }
}

package enum GPUWindowPresenterStateError: Error, Equatable, Sendable, CustomStringConvertible {
    case retired(GPUWindowPresenterRetireReason)
    case pool(GBMBufferPoolStateError)

    package var description: String {
        switch self {
        case .retired(let reason):
            "GPU window presenter retired: \(reason.description)"
        case .pool(let error):
            error.description
        }
    }
}

package enum GPUWindowPresenterError: Error, CustomStringConvertible {
    case state(GPUWindowPresenterStateError)
    case missingBuffer(GBMBufferPoolSlotID)
    case releaseFailure(GPUWindowPresenterStateError)
    case window(any Error)

    package var description: String {
        switch self {
        case .state(let error):
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
    private var retireReason: GPUWindowPresenterRetireReason?

    package init() {
        // Slots are installed as dmabuf wl_buffers become available.
    }

    package var isRetired: Bool {
        retireReason != nil
    }

    package var installedSlotIDs: [GBMBufferPoolSlotID] {
        poolState.slotIDs
    }

    package var outstandingSubmittedSlotIDs: [GBMBufferPoolSlotID] {
        poolState.submittedSlotIDs
    }

    package func lifecycle(
        for slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> GBMBufferPoolSlotLifecycle {
        try mapPoolError {
            try poolState.lifecycle(for: slotID)
        }
    }

    package mutating func installSlot(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        try mapPoolError {
            try poolState.insertAvailableSlot(slotID)
        }
    }

    package mutating func leaseNext()
        throws(GPUWindowPresenterStateError) -> GPUWindowPresentationLease
    {
        try ensureLive()
        let slotID = try mapPoolError {
            try poolState.leaseNextAvailableSlot()
        }
        return GPUWindowPresentationLease(slotID: slotID)
    }

    package mutating func markSubmitted(
        _ lease: GPUWindowPresentationLease,
        generation: UInt64
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        try mapPoolError {
            try poolState.markSubmitted(
                lease.slotID,
                commitGeneration: generation
            )
        }
    }

    package mutating func cancelLease(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        try mapPoolError {
            try poolState.cancelLease(lease.slotID)
        }
    }

    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) {
        guard !isRetired else { return }

        try mapPoolError {
            try poolState.markReleased(slotID)
        }
    }

    package mutating func retireAll(reason: GPUWindowPresenterRetireReason) {
        retireReason = reason
        poolState = GBMBufferPoolState()
    }

    private func ensureLive() throws(GPUWindowPresenterStateError) {
        if let retireReason {
            throw .retired(retireReason)
        }
    }

    private func mapPoolError<Value>(
        _ operation: () throws -> Value
    ) throws(GPUWindowPresenterStateError) -> Value {
        do {
            return try operation()
        } catch let error as GBMBufferPoolStateError {
            throw .pool(error)
        } catch {
            preconditionFailure("Unexpected GBM buffer pool error: \(error)")
        }
    }
}

@safe
package final class GPUWindowPresenter {
    private var state = GPUWindowPresenterState()
    private var buffers: [GBMBufferPoolSlotID: RawLinuxDmabufBuffer] = [:]
    private var releaseFailures: [GPUWindowPresenterStateError] = []

    package init() {
        // Buffers are installed after dmabuf import completes.
    }

    package var installedSlotIDs: [GBMBufferPoolSlotID] {
        buffers.keys.sorted()
    }

    package var outstandingSubmittedSlotIDs: [GBMBufferPoolSlotID] {
        state.outstandingSubmittedSlotIDs
    }

    package var releaseFailuresSnapshot: [GPUWindowPresenterStateError] {
        releaseFailures
    }

    package func installBuffer(
        _ buffer: RawLinuxDmabufBuffer,
        slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterError) {
        do {
            try state.installSlot(slotID)
        } catch {
            throw GPUWindowPresenterError.state(error)
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
            throw GPUWindowPresenterError.state(error)
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
            throw GPUWindowPresenterError.state(.pool(error))
        } catch let error as GPUWindowPresenterStateError {
            try cancelLeaseAfterFailedPresentation(lease)
            throw GPUWindowPresenterError.state(error)
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
            throw GPUWindowPresenterError.state(error)
        }
    }

    private func recordRelease(_ slotID: GBMBufferPoolSlotID) {
        do {
            try state.markReleased(slotID)
        } catch {
            releaseFailures.append(error)
        }
    }

    package func retireAll(reason: GPUWindowPresenterRetireReason) {
        for buffer in buffers.values {
            buffer.destroy()
        }

        buffers.removeAll()
        releaseFailures.removeAll()
        state.retireAll(reason: reason)
    }
}
