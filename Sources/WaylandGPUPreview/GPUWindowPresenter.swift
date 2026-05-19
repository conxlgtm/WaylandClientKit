// swiftlint:disable file_length
import WaylandClient
import WaylandGraphicsCore
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
    package let metadata: SurfaceCommitMetadata
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

    package var availableSlotIDs: [GBMBufferPoolSlotID] {
        poolState.availableSlotIDs
    }

    package var bufferPoolReadiness: GPUBufferPoolReadiness {
        guard !isRetired else { return .retired }
        let installedCount = poolState.slotIDs.count
        guard installedCount > 0 else { return .empty }

        let availableCount = poolState.availableSlotIDs.count
        let submittedCount = poolState.submittedSlotIDs.count
        guard availableCount > 0 else {
            return .exhausted(
                installedSlots: installedCount,
                submittedSlots: submittedCount
            )
        }

        return .ready(
            installedSlots: installedCount,
            availableSlots: availableCount,
            submittedSlots: submittedCount
        )
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

    @discardableResult
    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> Bool {
        guard !isRetired else { return false }
        let lifecycle = try lifecycle(for: slotID)
        guard case .submitted = lifecycle else { return false }
        guard explicitSubmissions[slotID] == nil else { return false }

        try mapPoolError {
            try poolState.markReleased(slotID)
        }
        return true
    }

    @discardableResult
    package mutating func markExplicitReleaseSignaled(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> Bool {
        guard !isRetired else { return false }
        let lifecycle = try lifecycle(for: slotID)
        guard case .submitted = lifecycle else { return false }
        explicitSubmissions.removeValue(forKey: slotID)

        try mapPoolError {
            try poolState.markReleased(slotID)
        }
        return true
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
    private var backingState = GPUWindowBackingState.unconfigured

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

    package var backingStateSnapshot: GPUWindowBackingState {
        var snapshot = backingState
        snapshot.bufferPool = state.bufferPoolReadiness
        return snapshot
    }

    package func correlatedSlotID(
        forPresentationGeneration generation: UInt64
    ) -> GBMBufferPoolSlotID? {
        presentationCorrelation.takeSlotID(for: generation)
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
        if backingState.lifecycle == .unconfigured {
            backingState.lifecycle = .configuring
        }
        backingState.bufferPool = state.bufferPoolReadiness
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
            pacing: .none,
            metadata: .default
        )
    }

    package func presentNext(
        on window: TopLevelWindow,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata = .default
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        if let releaseFailure = releaseFailures.first {
            throw GPUWindowPresenterError.releaseFailure(releaseFailure)
        }

        let (lease, buffer) = try leaseBufferForPresentation()

        let presentation: PreviewBufferPresentationResult
        do {
            let submitConstraints = SurfaceSubmitConstraints(
                synchronization: synchronization.submitConstraint,
                pacing: pacing
            )
            presentation = try window.presentPreviewBufferOnOwnerThread(
                buffer.surfaceBuffer,
                submitConstraints: submitConstraints,
                metadata: metadata
            )
        } catch let error as GBMBufferPoolStateError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                .gbmAllocationFailed,
                operation: .gbmAllocation
            )
            throw GPUWindowPresenterError.state(.pool(error))
        } catch let error as GPUWindowPresenterStateError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                .submitConstraintRejected,
                operation: .submitConstraintApplication
            )
            throw GPUWindowPresenterError.state(error)
        } catch {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(.commitFailed, operation: .surfaceCommit)
            throw GPUWindowPresenterError.window(error)
        }

        return try recordPresentedFrameAfterCommit(
            presentation,
            lease: lease,
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata
        )
    }

    private func leaseBufferForPresentation()
        throws(GPUWindowPresenterError) -> (
            GPUWindowPresentationLease, any GPUWindowPresenterBuffer
        )
    {
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

        return (lease, buffer)
    }

    private func recordSuccessfulPresentation(
        _ presentation: PreviewBufferPresentationResult,
        lease: GPUWindowPresentationLease,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata
    ) throws(GPUWindowPresenterStateError) -> GPUWindowPresentedFrame {
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
            pacing: pacing,
            metadata: metadata
        )
        presentationCorrelation.record(frame)
        runtimePath = GPURuntimePathSnapshot.afterPresentation(
            capabilities: presentation.capabilities,
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata
        )
        backingState.markReady(
            runtimePath: runtimePath,
            capabilities: presentation.capabilities,
            bufferPool: state.bufferPoolReadiness,
            frame: frame
        )
        return frame
    }

    private func recordPresentedFrameAfterCommit(
        _ presentation: PreviewBufferPresentationResult,
        lease: GPUWindowPresentationLease,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        do {
            return try recordSuccessfulPresentation(
                presentation,
                lease: lease,
                synchronization: synchronization,
                pacing: pacing,
                metadata: metadata
            )
        } catch {
            throw GPUWindowPresenterError.state(error)
        }
    }

    private func recordBackingFailure(
        _ failure: GPUBackingFailure,
        operation: GPUBackingOperation
    ) {
        backingState.markFailed(failure, operation: operation)
        runtimePath = backingState.runtimePath
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
            if try state.markReleased(slotID) {
                presentationCorrelation.remove(slotID: slotID)
            }
        } catch {
            releaseFailures.append(error)
        }
    }

    package func recordExplicitReleaseSignal(
        slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterError) {
        do {
            if try state.markExplicitReleaseSignaled(slotID) {
                presentationCorrelation.remove(slotID: slotID)
            }
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
        backingState.markRetired()
    }

    deinit {
        retireAll(reason: .windowClosed)
    }
}

extension GPUWindowPresenter {
    package func leaseNextForTesting()
        throws(GPUWindowPresenterError) -> GPUWindowPresentationLease
    {
        let (lease, _) = try leaseBufferForPresentation()
        return lease
    }

    package func recordPresentedFrameForTesting(
        generation: UInt64,
        commitPlan: SurfaceCommitPlan,
        capabilities: SurfaceCapabilitySnapshot,
        lease: GPUWindowPresentationLease,
        synchronization: GPUBufferSubmissionSynchronization = .implicit,
        pacing: SurfacePacingConstraint = .none,
        metadata: SurfaceCommitMetadata = .default
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        try recordPresentedFrameAfterCommit(
            PreviewBufferPresentationResult(
                generation: generation,
                commitPlan: commitPlan,
                capabilities: capabilities
            ),
            lease: lease,
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata
        )
    }

    package func markReadyForTesting(
        capabilities: SurfaceCapabilitySnapshot,
        synchronization: GPUBufferSubmissionSynchronization = .implicit,
        pacing: SurfacePacingConstraint = .none,
        metadata: SurfaceCommitMetadata = .default
    ) {
        runtimePath = .afterPresentation(
            capabilities: capabilities,
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata
        )
        backingState.markReady(
            runtimePath: runtimePath,
            capabilities: capabilities,
            bufferPool: state.bufferPoolReadiness,
            frame: nil
        )
    }

    package func markFailureForTesting(
        _ failure: GPUBackingFailure,
        operation: GPUBackingOperation
    ) {
        recordBackingFailure(failure, operation: operation)
    }
}
