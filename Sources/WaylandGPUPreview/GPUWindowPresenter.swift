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
    case submitConstraints(SurfaceSubmitConstraintError)
    case metadata(SurfaceCommitMetadataError)
    case window(any Error)

    package var description: String {
        switch self {
        case .state(let error):
            error.description
        case .missingBuffer(let slotID):
            "missing GPU buffer for slot \(slotID.rawValue)"
        case .releaseFailure(let error):
            "GPU buffer release failed: \(error.description)"
        case .submitConstraints(let error):
            "GPU submit constraints failed: \(String(describing: error))"
        case .metadata(let error):
            "GPU metadata failed: \(error.description)"
        case .window(let error):
            "GPU window presentation failed: \(String(describing: error))"
        }
    }
}

package typealias GPUWindowBufferPresentationSubmitter =
    (
        RawSurfaceBuffer,
        SurfaceSubmitConstraints,
        SurfaceCommitMetadata
    ) async throws -> PreviewBufferPresentationResult

private struct GPUWindowPresentationOptions {
    let synchronization: GPUBufferSubmissionSynchronization
    let pacing: SurfacePacingConstraint
    let metadata: SurfaceCommitMetadata

    var submitConstraints: SurfaceSubmitConstraints {
        SurfaceSubmitConstraints(
            synchronization: synchronization.submitConstraint,
            pacing: pacing
        )
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
        case .committedUntracked:
            return .committedUntracked
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

    package mutating func leaseSlot(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> GPUWindowPresentationLease {
        try ensureLive()
        let leasedSlotID = try mapPoolError {
            try poolState.leaseAvailableSlot(slotID)
        }
        return GPUWindowPresentationLease(slotID: leasedSlotID)
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

    package mutating func markCommittedUntracked(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterStateError) {
        try ensureLive()
        explicitSubmissions.removeValue(forKey: lease.slotID)
        try mapPoolError {
            try poolState.markCommittedUntracked(lease.slotID)
        }
    }

    @discardableResult
    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterStateError) -> Bool {
        guard !isRetired else { return false }
        let lifecycle = try lifecycle(for: slotID)
        guard lifecycle.isInCompositorUse else { return false }
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
        guard lifecycle.isInCompositorUse else { return false }
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

    deinit {
        retireAll(reason: .windowClosed)
    }
}

extension GPUWindowPresenter {
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

        let options = GPUWindowPresentationOptions(
            synchronization: synchronization,
            pacing: pacing,
            metadata: metadata
        )
        let (lease, buffer) = try leaseBufferForPresentation()

        let presentation: PreviewBufferPresentationResult
        do {
            presentation = try window.presentPreviewBufferOnOwnerThread(
                buffer.surfaceBuffer,
                submitConstraints: options.submitConstraints,
                metadata: options.metadata
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
        } catch let error as SurfaceSubmitConstraintError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                GPUBackingFailure(error),
                operation: .submitConstraintApplication
            )
            throw GPUWindowPresenterError.submitConstraints(error)
        } catch let error as SurfaceCommitMetadataError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                .metadataRequiredButUnavailable(error),
                operation: .metadataSetup
            )
            throw GPUWindowPresenterError.metadata(error)
        } catch {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(.commitFailed, operation: .surfaceCommit)
            throw GPUWindowPresenterError.window(error)
        }

        return try recordPresentedFrameAfterCommit(
            presentation,
            lease: lease,
            options: options
        )
    }

    package func presentNext(
        submit: GPUWindowBufferPresentationSubmitter,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata = .default
    ) async throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        if let releaseFailure = releaseFailures.first {
            throw GPUWindowPresenterError.releaseFailure(releaseFailure)
        }

        let (lease, buffer) = try leaseBufferForPresentation()
        return try await present(
            lease: lease,
            buffer: buffer,
            submit: submit,
            options: GPUWindowPresentationOptions(
                synchronization: synchronization,
                pacing: pacing,
                metadata: metadata
            )
        )
    }

    package func presentSlot(
        _ slotID: GBMBufferPoolSlotID,
        submit: GPUWindowBufferPresentationSubmitter,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint,
        metadata: SurfaceCommitMetadata = .default
    ) async throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        if let releaseFailure = releaseFailures.first {
            throw GPUWindowPresenterError.releaseFailure(releaseFailure)
        }

        let (lease, buffer) = try leaseBufferForPresentation(slotID: slotID)
        return try await present(
            lease: lease,
            buffer: buffer,
            submit: submit,
            options: GPUWindowPresentationOptions(
                synchronization: synchronization,
                pacing: pacing,
                metadata: metadata
            )
        )
    }

    private func present(
        lease: GPUWindowPresentationLease,
        buffer: any GPUWindowPresenterBuffer,
        submit: GPUWindowBufferPresentationSubmitter,
        options: GPUWindowPresentationOptions
    ) async throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        let presentation: PreviewBufferPresentationResult
        do {
            presentation = try await submit(
                buffer.surfaceBuffer,
                options.submitConstraints,
                options.metadata
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
        } catch let error as SurfaceSubmitConstraintError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                GPUBackingFailure(error),
                operation: .submitConstraintApplication
            )
            throw GPUWindowPresenterError.submitConstraints(error)
        } catch let error as SurfaceCommitMetadataError {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(
                .metadataRequiredButUnavailable(error),
                operation: .metadataSetup
            )
            throw GPUWindowPresenterError.metadata(error)
        } catch {
            try cancelLeaseAfterFailedPresentation(lease)
            recordBackingFailure(.commitFailed, operation: .surfaceCommit)
            throw GPUWindowPresenterError.window(error)
        }

        return try recordPresentedFrameAfterCommit(
            presentation,
            lease: lease,
            options: options
        )
    }

    private func leaseBufferForPresentation(
        slotID: GBMBufferPoolSlotID
    ) throws(GPUWindowPresenterError) -> (
        GPUWindowPresentationLease, any GPUWindowPresenterBuffer
    ) {
        let lease: GPUWindowPresentationLease
        do {
            lease = try state.leaseSlot(slotID)
        } catch {
            throw GPUWindowPresenterError.state(error)
        }

        guard let buffer = buffers[lease.slotID] else {
            try cancelLeaseAfterFailedPresentation(lease)
            throw GPUWindowPresenterError.missingBuffer(lease.slotID)
        }

        return (lease, buffer)
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

    private func cancelLeaseAfterFailedPresentation(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterError) {
        do {
            try state.cancelLease(lease)
        } catch {
            throw GPUWindowPresenterError.state(error)
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
}

extension GPUWindowPresenter {
    private func recordSuccessfulPresentation(
        _ presentation: PreviewBufferPresentationResult,
        lease: GPUWindowPresentationLease,
        options: GPUWindowPresentationOptions
    ) throws(GPUWindowPresenterStateError) -> GPUWindowPresentedFrame {
        try state.markSubmitted(
            lease,
            generation: presentation.generation,
            synchronization: options.synchronization
        )
        let frame = GPUWindowPresentedFrame(
            slotID: lease.slotID,
            generation: presentation.generation,
            commitPlan: presentation.commitPlan,
            synchronization: options.synchronization,
            pacing: options.pacing,
            metadata: options.metadata
        )
        presentationCorrelation.record(frame)
        runtimePath = GPURuntimePathSnapshot.afterPresentation(
            capabilities: presentation.capabilities,
            synchronization: options.synchronization,
            pacing: options.pacing,
            metadata: options.metadata
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
        options: GPUWindowPresentationOptions
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        do {
            return try recordSuccessfulPresentation(
                presentation,
                lease: lease,
                options: options
            )
        } catch {
            markCommittedUntrackedAfterTrackingFailure(lease)
            recordBackingFailure(
                .presentationTrackingFailed,
                operation: .presentationTracking
            )
            throw GPUWindowPresenterError.state(error)
        }
    }

    private func markCommittedUntrackedAfterTrackingFailure(
        _ lease: GPUWindowPresentationLease
    ) {
        do {
            try state.markCommittedUntracked(lease)
        } catch {
            releaseFailures.append(error)
        }
    }

    private func recordBackingFailure(
        _ failure: GPUBackingFailure,
        operation: GPUBackingOperation
    ) {
        backingState.markFailed(failure, operation: operation)
        runtimePath = backingState.runtimePath
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
}

extension GPUWindowPresenter {
    package func leaseNextForTesting()
        throws(GPUWindowPresenterError) -> GPUWindowPresentationLease
    {
        let (lease, _) = try leaseBufferForPresentation()
        return lease
    }

    package func cancelLeaseForTesting(
        _ lease: GPUWindowPresentationLease
    ) throws(GPUWindowPresenterError) {
        try cancelLeaseAfterFailedPresentation(lease)
    }

    package func recordPresentedFrameForTesting(
        _ presentation: PreviewBufferPresentationResult,
        lease: GPUWindowPresentationLease,
        synchronization: GPUBufferSubmissionSynchronization = .implicit,
        pacing: SurfacePacingConstraint = .none,
        metadata: SurfaceCommitMetadata = .default
    ) throws(GPUWindowPresenterError) -> GPUWindowPresentedFrame {
        try recordPresentedFrameAfterCommit(
            presentation,
            lease: lease,
            options: GPUWindowPresentationOptions(
                synchronization: synchronization,
                pacing: pacing,
                metadata: metadata
            )
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
