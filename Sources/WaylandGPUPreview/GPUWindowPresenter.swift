import WaylandClient
import WaylandGraphicsPreview
import WaylandRaw

package protocol GPUWindowPresenterBuffer: AnyObject {
    var surfaceBuffer: RawSurfaceBuffer { get }

    func setReleaseObserver(_ observer: @escaping () -> Void)
    func destroy()
}

extension RawLinuxDmabufBuffer: GPUWindowPresenterBuffer {}

package struct GPUWindowPresentationLease: Equatable, Sendable {
    package let slotID: GBMBufferPoolSlotID
}

package struct GPUWindowPresentedFrame: Equatable, Sendable {
    package let slotID: GBMBufferPoolSlotID
    package let generation: UInt64
    package let commitPlan: SurfaceCommitPlan
    package let synchronization: GPUBufferSubmissionSynchronization
    package let pacing: SurfacePacingConstraint
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
    private var explicitSubmissions: [GBMBufferPoolSlotID: GPUSubmittedBufferSyncState] = [:]
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

    package func submissionState(
        for slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> GPUBufferSubmissionState {
        if isRetired {
            return .retired
        }

        let lifecycle = try lifecycle(for: slotID)
        switch lifecycle {
        case .available:
            return .available
        case .leased:
            return .leased
        case .submitted(let generation):
            if let explicitSubmission = explicitSubmissions[slotID] {
                return .submittedExplicit(
                    commitGeneration: generation,
                    releasePoint: explicitSubmission.releasePoint
                )
            }

            return .submittedImplicit(commitGeneration: generation)
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
        try markSubmitted(
            lease,
            generation: generation,
            synchronization: .implicit
        )
    }

    package mutating func markSubmitted(
        _ lease: GPUWindowPresentationLease,
        generation: UInt64,
        synchronization: GPUBufferSubmissionSynchronization
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        try mapPoolError {
            try poolState.markSubmitted(
                lease.slotID,
                commitGeneration: generation
            )
        }

        switch synchronization {
        case .implicit:
            explicitSubmissions.removeValue(forKey: lease.slotID)
        case .explicit(let syncState):
            explicitSubmissions[lease.slotID] = syncState
        }
    }

    package mutating func cancelLease(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        explicitSubmissions.removeValue(forKey: lease.slotID)
        try mapPoolError {
            try poolState.cancelLease(lease.slotID)
        }
    }

    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) {
        guard !isRetired else { return }
        guard explicitSubmissions[slotID] == nil else { return }

        try mapPoolError {
            try poolState.markReleased(slotID)
        }
    }

    package mutating func markExplicitReleaseSignaled(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) {
        guard !isRetired else { return }
        explicitSubmissions.removeValue(forKey: slotID)

        try mapPoolError {
            try poolState.markReleased(slotID)
        }
    }

    package mutating func retireAll(reason: GPUWindowPresenterRetireReason) {
        retireReason = reason
        explicitSubmissions.removeAll()
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
    private var buffers: [GBMBufferPoolSlotID: any GPUWindowPresenterBuffer] = [:]
    private var releaseFailures: [GPUWindowPresenterStateError] = []
    private var presentationCorrelation = GPUWindowPresentationCorrelation()
    private var runtimePath = GPURuntimePathSnapshot.empty

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

    package var runtimePathSnapshot: GPURuntimePathSnapshot {
        runtimePath
    }

    package func correlatedSlotID(
        forPresentationGeneration generation: UInt64
    ) -> GBMBufferPoolSlotID? {
        presentationCorrelation.slotID(for: generation)
    }

    package func installBuffer(
        _ buffer: any GPUWindowPresenterBuffer,
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
        try presentNext(
            on: window,
            synchronization: .implicit,
            pacing: .none
        )
    }

    package func presentNext(
        on window: TopLevelWindow,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint
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
            let submitConstraints = SurfaceSubmitConstraints(
                synchronization: synchronization.submitConstraint,
                pacing: pacing
            )
            let presentation = try window.presentPreviewBufferOnOwnerThread(
                buffer.surfaceBuffer,
                submitConstraints: submitConstraints
            )
            try state.markSubmitted(
                lease,
                generation: presentation.generation,
                synchronization: synchronization
            )
            let frame = GPUWindowPresentedFrame(
                slotID: lease.slotID,
                generation: presentation.generation,
                commitPlan: presentation.commitPlan,
                synchronization: synchronization,
                pacing: pacing
            )
            presentationCorrelation.record(frame)
            runtimePath = runtimePathSnapshotAfterPresentation(
                synchronization: synchronization,
                pacing: pacing
            )
            return frame
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

    package func recordExplicitReleaseSignal(
        slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterError) {
        do {
            try state.markExplicitReleaseSignaled(slotID)
        } catch {
            throw .state(error)
        }
    }

    package func retireAll(reason: GPUWindowPresenterRetireReason) {
        for buffer in buffers.values {
            buffer.destroy()
        }

        buffers.removeAll()
        releaseFailures.removeAll()
        presentationCorrelation.removeAll()
        runtimePath = .empty
        state.retireAll(reason: reason)
    }

    private func runtimePathSnapshotAfterPresentation(
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint
    ) -> GPURuntimePathSnapshot {
        GPURuntimePathSnapshot(
            dmabuf: .active,
            gbm: .active,
            egl: .available,
            synchronization: runtimeSynchronizationStatus(synchronization),
            pacing: runtimePacingStatus(pacing),
            presentationFeedback: .unavailable
        )
    }

    private func runtimeSynchronizationStatus(
        _ synchronization: GPUBufferSubmissionSynchronization
    ) -> GPUSynchronizationRuntimeStatus {
        switch synchronization {
        case .implicit:
            .implicit
        case .explicit:
            .explicitActive
        }
    }

    private func runtimePacingStatus(
        _ pacing: SurfacePacingConstraint
    ) -> GPUFramePacingRuntimeStatus {
        switch pacing {
        case .none:
            .none
        case .fifo:
            .fifoActive
        case .targetTime:
            .commitTimingActive
        case .fifoAndTargetTime:
            .fifoAndCommitTimingActive
        }
    }

    deinit {
        retireAll(reason: .windowClosed)
    }
}
