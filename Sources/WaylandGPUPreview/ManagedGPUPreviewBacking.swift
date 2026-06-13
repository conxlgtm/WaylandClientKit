import Glibc
import WaylandClient
import WaylandGraphicsCore
import WaylandRaw

package enum ManagedGPUPreviewBackingError: Error, CustomStringConvertible {
    case setup(GPUBackingFailure)
    case render(EGLRenderError)
    case allocation(GBMAllocationError)
    case dmabufImport(GPUDmabufBufferImportError)
    case runtime(RuntimeError)
    case presentation(GPUWindowPresenterError)
    case closed

    package var failure: GPUBackingFailure {
        switch self {
        case .setup(let failure):
            failure
        case .render:
            .eglUnavailable
        case .allocation(let error):
            Self.backingFailure(for: error)
        case .dmabufImport:
            .compositorRejectedBuffer
        case .runtime:
            .commitFailed
        case .presentation(let error):
            Self.backingFailure(for: error)
        case .closed:
            .commitFailed
        }
    }

    package var fallbackReason: GPUFallbackReason {
        switch failure {
        case .dmabufUnavailable:
            .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            .surfaceFeedbackUnavailable
        case .noCompatibleFormat:
            .noCompatibleFormat
        case .noRenderNode:
            .noRenderNode
        case .gbmUnavailable:
            .gbmUnavailable
        case .gbmAllocationFailed:
            .gbmAllocationFailed
        case .eglUnavailable:
            .eglUnavailable
        case .explicitSyncRequiredButUnavailable:
            .explicitSyncRequiredButUnavailable
        case .fifoRequiredButUnavailable:
            .fifoRequiredButUnavailable
        case .commitTimingRequiredButUnavailable:
            .commitTimingRequiredButUnavailable
        case .metadataRequiredButUnavailable(let error):
            .metadataRequiredButUnavailable(error)
        case .compositorRejectedBuffer, .submitConstraintRejected:
            .compositorRejectedBuffer
        case .commitTimingRejected:
            .commitTimingRejected
        case .commitFailed:
            .commitFailed
        case .presentationTrackingFailed:
            .presentationTrackingFailed
        }
    }

    package var description: String {
        switch self {
        case .setup(let failure):
            failure.description
        case .render(let error):
            error.description
        case .allocation(let error):
            error.description
        case .dmabufImport(let error):
            error.description
        case .runtime(let error):
            error.description
        case .presentation(let error):
            error.description
        case .closed:
            "managed GPU backing is closed"
        }
    }

    package static func backingFailure(for error: GBMAllocationError) -> GPUBackingFailure {
        switch error {
        case .invalidRenderNodeFileDescriptor,
            .invalidDeviceIDByteCount,
            .renderNodeLookupFailed,
            .openRenderNodeFailed:
            .noRenderNode
        case .deviceCreationFailed, .deviceDestroyed:
            .gbmUnavailable
        case .invalidBufferDimensions,
            .bufferAllocationFailed,
            .surfaceCreationFailed,
            .bufferDestroyed,
            .surfaceDestroyed,
            .surfaceFrontBufferLockFailed,
            .exportFailed,
            .syncobjCreationFailed,
            .syncobjFileDescriptorExportFailed,
            .syncobjTimelineSignalFailed,
            .invalidPlaneIndex,
            .planeFileDescriptorAlreadyTaken:
            .gbmAllocationFailed
        }
    }

    package static func backingFailure(for error: GPUWindowPresenterError) -> GPUBackingFailure {
        switch error {
        case .submitConstraints:
            .submitConstraintRejected
        case .metadata(let metadataError):
            .metadataRequiredButUnavailable(metadataError)
        case .missingBuffer, .state, .releaseFailure:
            .gbmAllocationFailed
        case .window:
            .commitFailed
        }
    }
}

private struct ManagedGPUPreviewPresentationOptions {
    let metadata: SurfaceCommitMetadata
    let synchronization: ManagedGPUPreviewSynchronizationSelection
    let pacing: SurfacePacingConstraint
    let pacingFallbackReason: GPURuntimePathReason?
    let requestPresentationFeedback: Bool
}

private enum ManagedGPUPreviewSynchronizationSelection {
    case implicit(fallbackReason: GPURuntimePathReason? = nil)
    case explicit(ManagedGPUExplicitSynchronization)

    var fallbackReason: GPURuntimePathReason? {
        switch self {
        case .implicit(let fallbackReason):
            fallbackReason
        case .explicit:
            nil
        }
    }

    var requirementSynchronization: GPUBufferSubmissionSynchronization {
        switch self {
        case .implicit:
            .implicit
        case .explicit(let explicitSynchronization):
            .explicit(explicitSynchronization.placeholderSubmissionState)
        }
    }

    func submissionSynchronization(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMAllocationError) -> GPUBufferSubmissionSynchronization {
        switch self {
        case .implicit:
            .implicit
        case .explicit(let explicitSynchronization):
            try .explicit(explicitSynchronization.submissionState(for: slotID))
        }
    }
}

private final class ManagedGPUExplicitSynchronization {
    private let timeline: DRMSyncobjTimeline
    private let identity: GPUSyncTimeline
    private var nextPoint: UInt64 = 1

    init(
        timeline syncTimeline: DRMSyncobjTimeline,
        identity timelineIdentity: GPUSyncTimeline
    ) {
        timeline = syncTimeline
        identity = timelineIdentity
    }

    var explicitSynchronization: GPUExplicitSynchronization {
        GPUExplicitSynchronization(acquireTimeline: identity, releaseTimeline: identity)
    }

    var placeholderSubmissionState: GPUSubmittedBufferSyncState {
        GPUSubmittedBufferSyncState(
            slotID: placeholderSlotID(),
            acquirePoint: GPUSyncPoint(
                timeline: identity,
                point: RawSyncobjTimelinePoint(1)
            ),
            releasePoint: GPUSyncPoint(
                timeline: identity,
                point: RawSyncobjTimelinePoint(2)
            )
        )
    }

    private func placeholderSlotID() -> GBMBufferPoolSlotID {
        do {
            return try GBMBufferPoolSlotID(0)
        } catch {
            preconditionFailure("Zero is always a valid GPU buffer slot ID")
        }
    }

    func submissionState(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMAllocationError) -> GPUSubmittedBufferSyncState {
        let acquirePoint = RawSyncobjTimelinePoint(nextPoint)
        let releasePoint = RawSyncobjTimelinePoint(nextPoint + 1)
        nextPoint += 2

        try timeline.signal(acquirePoint)

        return GPUSubmittedBufferSyncState(
            slotID: slotID,
            acquirePoint: GPUSyncPoint(
                timeline: identity,
                point: acquirePoint
            ),
            releasePoint: GPUSyncPoint(
                timeline: identity,
                point: releasePoint
            )
        )
    }

    func destroy() {
        timeline.destroy()
    }
}

// swiftlint:disable:next type_body_length
package final class ManagedGPUPreviewBacking {
    private let window: Window
    private let presenter = GPUWindowPresenter()
    private var device: GBMDevice?
    private var renderTarget: EGLGBMRenderTarget?
    private var explicitSynchronization: ManagedGPUExplicitSynchronization?
    private var configuredGeometry: SurfaceGeometry?
    private var capabilities: SurfaceCapabilitySnapshot?
    private var runtimePath = GPURuntimePathSnapshot.empty
    private var nextSlotRawValue = 0
    private var nextSyncTimelineRawValue: UInt64 = 1
    private var isClosed = false

    package init(window backingWindow: Window) {
        window = backingWindow
    }

    package var runtimePathSnapshot: GPURuntimePathSnapshot {
        runtimePath == .empty ? presenter.runtimePathSnapshot : runtimePath
    }

    package var surfaceCapabilities: SurfaceCapabilitySnapshot? {
        capabilities
    }

    package func close() {
        isClosed = true
        presenter.retireAll(reason: .windowClosed)
        explicitSynchronization?.destroy()
        explicitSynchronization = nil
        renderTarget?.destroy()
        renderTarget = nil
        configuredGeometry = nil
        device?.destroy()
        device = nil
        capabilities = nil
        runtimePath = .empty
    }

    deinit {
        close()
    }

    package func ensureConfigured(
        geometry: SurfaceGeometry,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultDiscoveryTimeoutMilliseconds
    ) async throws(ManagedGPUPreviewBackingError) {
        guard !isClosed else {
            throw .closed
        }
        if Self.canReuseRenderTarget(
            configuredGeometry: configuredGeometry,
            requestedGeometry: geometry
        ) {
            return
        }
        if renderTarget != nil {
            try prepareForGeometryReconfiguration()
        }

        let surfaceCapabilities: SurfaceCapabilitySnapshot
        do {
            surfaceCapabilities = try await window.requestGraphicsPreviewSurfaceFeedback(
                timeoutMilliseconds: timeoutMilliseconds
            )
        } catch let error as GraphicsPreviewSurfaceFeedbackError {
            throw .setup(Self.failure(for: error))
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.surfaceFeedbackUnavailable)
        }
        capabilities = surfaceCapabilities
        runtimePath = .afterCapabilityDiscovery(capabilities: surfaceCapabilities)

        let feedback = try surfaceFeedback(from: surfaceCapabilities)
        let selection = try selectFormat(from: feedback)
        let gbmDevice = try createDevice(for: selection)
        device = gbmDevice
        runtimePath = .afterGBMDeviceSelection(capabilities: surfaceCapabilities)

        let target = try createRenderTarget(
            device: gbmDevice,
            formatModifier: selection.formatModifier,
            geometry: geometry
        )
        renderTarget = target
        configuredGeometry = geometry
        runtimePath = .afterEGLTargetSetup(capabilities: surfaceCapabilities)
    }

    @discardableResult
    package func submitClearFrame(
        color: GPUClearColor,
        metadata: SurfaceCommitMetadata,
        geometry: SurfaceGeometry,
        synchronizationPolicy: GPUSynchronizationPolicy = .implicitOnly,
        pacingPolicy: GPUFramePacingPolicy = .none,
        requestPresentationFeedback: Bool = false
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        do {
            try await ensureConfigured(geometry: geometry)
        } catch let error {
            recordFailure(error)
            throw error
        }
        guard let renderTarget, let capabilities else {
            throw .closed
        }

        let synchronization: ManagedGPUPreviewSynchronizationSelection
        do {
            synchronization = try await resolveSynchronization(
                policy: synchronizationPolicy,
                capabilities: capabilities
            )
        } catch let error {
            recordFailure(error)
            throw error
        }

        let pacingSelection: GPUFramePacingPolicySelection
        do {
            pacingSelection = try resolvePacing(
                policy: pacingPolicy,
                capabilities: capabilities
            )
        } catch let error {
            recordFailure(error)
            throw error
        }

        do {
            try GPUBackingRequirements(
                synchronization: synchronization.requirementSynchronization,
                pacing: pacingSelection.constraint,
                metadata: metadata
            ).validate(capabilities: capabilities)
        } catch {
            let failure = GPUBackingFailure(error)
            recordFailure(failure)
            throw .setup(failure)
        }

        let imported: (buffer: RawLinuxDmabufBuffer, lockedBuffer: GBMLockedSurfaceBuffer)
        do {
            imported = try await renderAndImportBuffer(
                renderTarget: renderTarget,
                color: color
            )
        } catch let error {
            recordFailure(error)
            throw error
        }
        runtimePath = .afterDmabufImportSetup(capabilities: capabilities)
        do {
            return try await presentImportedBuffer(
                imported,
                renderTarget: renderTarget,
                options: ManagedGPUPreviewPresentationOptions(
                    metadata: metadata,
                    synchronization: synchronization,
                    pacing: pacingSelection.constraint,
                    pacingFallbackReason: pacingSelection.fallbackReason,
                    requestPresentationFeedback: requestPresentationFeedback
                )
            )
        } catch let error {
            recordFailure(error)
            throw error
        }
    }

    private func renderAndImportBuffer(
        renderTarget: EGLGBMRenderTarget,
        color: GPUClearColor
    ) async throws(ManagedGPUPreviewBackingError) -> (
        buffer: RawLinuxDmabufBuffer,
        lockedBuffer: GBMLockedSurfaceBuffer
    ) {
        do {
            _ = try renderTarget.drawClear(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
            let lockedBuffer = try renderTarget.lockFrontBuffer()
            let export = try lockedBuffer.exportDmabuf()
            // swiftlint:disable closure_parameter_position
            let importedBuffer = try await window.withGraphicsPreviewLinuxDmabuf {
                linuxDmabuf, syncDisplay in
                try GPUDmabufBufferImport.importBuffer(
                    from: export,
                    using: linuxDmabuf,
                    timeoutMilliseconds: WaylandDisplay.defaultDiscoveryTimeoutMilliseconds,
                    syncDisplay: syncDisplay
                )
            }
            // swiftlint:enable closure_parameter_position

            return (importedBuffer, lockedBuffer)
        } catch let error as EGLRenderError {
            throw .render(error)
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as GPUDmabufBufferImportError {
            throw .dmabufImport(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.commitFailed)
        }
    }

    private func presentImportedBuffer(
        _ imported: (buffer: RawLinuxDmabufBuffer, lockedBuffer: GBMLockedSurfaceBuffer),
        renderTarget: EGLGBMRenderTarget,
        options: ManagedGPUPreviewPresentationOptions
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        do {
            let slotID: GBMBufferPoolSlotID
            let previewBuffer = ManagedGPUPreviewBuffer(
                buffer: imported.buffer,
                lockedBuffer: imported.lockedBuffer,
                renderTarget: renderTarget
            )
            if let reusableSlotID = presenter.availableSlotIDs.first {
                slotID = reusableSlotID
                try presenter.replaceAvailableBuffer(previewBuffer, slotID: reusableSlotID)
            } else {
                slotID = try nextSlotID()
                try presenter.installBuffer(previewBuffer, slotID: slotID)
            }
            let synchronization = try options.synchronization.submissionSynchronization(
                for: slotID
            )
            let frame = try await presenter.presentSlot(
                slotID,
                submit: { [window] buffer, submitConstraints, commitMetadata in
                    try await window.presentGraphicsPreviewBuffer(
                        buffer,
                        submitConstraints: submitConstraints,
                        metadata: commitMetadata,
                        requestPresentationFeedback: options.requestPresentationFeedback
                    )
                },
                synchronization: synchronization,
                pacing: options.pacing,
                metadata: options.metadata
            )
            var snapshot = presenter.runtimePathSnapshot
            if let fallbackReason = options.synchronization.fallbackReason {
                snapshot = snapshot.markingSynchronizationFallback(fallbackReason)
            }
            if let fallbackReason = options.pacingFallbackReason {
                snapshot = snapshot.markingPacingFallback(fallbackReason)
            }
            runtimePath = snapshot
            if let surfaceCapabilities = presenter.backingStateSnapshot.surfaceCapabilities {
                capabilities = surfaceCapabilities
            }
            return frame
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as GPUWindowPresenterError {
            throw .presentation(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.commitFailed)
        }
    }

    private func resolveSynchronization(
        policy: GPUSynchronizationPolicy,
        capabilities: SurfaceCapabilitySnapshot
    ) async throws(ManagedGPUPreviewBackingError) -> ManagedGPUPreviewSynchronizationSelection {
        switch policy {
        case .implicitOnly:
            return .implicit()
        case .preferExplicitFallbackToImplicit:
            guard capabilities.synchronization.supportsExplicit else {
                return .implicit(fallbackReason: .explicitSynchronizationUnavailable)
            }
            do {
                return .explicit(
                    try await ensureExplicitSynchronizationConfigured()
                )
            } catch {
                return .implicit(fallbackReason: .explicitSynchronizationNotConfigured)
            }
        case .requireExplicit:
            guard capabilities.synchronization.supportsExplicit else {
                throw .setup(.explicitSyncRequiredButUnavailable)
            }
            do {
                return .explicit(
                    try await ensureExplicitSynchronizationConfigured()
                )
            } catch {
                throw .setup(.explicitSyncRequiredButUnavailable)
            }
        }
    }

    private func ensureExplicitSynchronizationConfigured()
        async throws(ManagedGPUPreviewBackingError) -> ManagedGPUExplicitSynchronization
    {
        if let explicitSynchronization {
            return explicitSynchronization
        }
        guard let device else {
            throw .setup(.explicitSyncRequiredButUnavailable)
        }

        do {
            let timelineIdentity = GPUSyncTimeline(nextSyncTimelineRawValue)
            nextSyncTimelineRawValue += 1
            let timeline = try DRMSyncobjTimeline(
                deviceFileDescriptor: try device.drmFileDescriptor
            )
            var timelineFileDescriptor = try timeline.exportFileDescriptor()
            try await window.importGraphicsPreviewSynchronizationTimeline(
                &timelineFileDescriptor,
                identity: SurfaceSyncTimelineIdentity(timelineIdentity.rawValue)
            )
            let synchronization = ManagedGPUExplicitSynchronization(
                timeline: timeline,
                identity: timelineIdentity
            )
            explicitSynchronization = synchronization
            return synchronization
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch let error as RuntimeError {
            throw .runtime(error)
        } catch {
            throw .setup(.explicitSyncRequiredButUnavailable)
        }
    }

    private func resolvePacing(
        policy: GPUFramePacingPolicy,
        capabilities: SurfaceCapabilitySnapshot
    ) throws(ManagedGPUPreviewBackingError) -> GPUFramePacingPolicySelection {
        do {
            return policy.selectConstraint(
                capability: capabilities.pacing,
                commitTimingTarget: try nextCommitTimingTarget()
            )
        } catch {
            throw .setup(.commitTimingRequiredButUnavailable)
        }
    }

    private func nextCommitTimingTarget()
        throws(SurfaceSubmitConstraintError) -> SurfaceCommitTargetTime
    {
        var timestamp = timespec()
        guard unsafe clock_gettime(CLOCK_MONOTONIC, &timestamp) == 0 else {
            return try SurfaceCommitTargetTime(seconds: 0, nanoseconds: 0)
        }

        var seconds = UInt64(timestamp.tv_sec)
        var nanoseconds = UInt32(timestamp.tv_nsec) + 16_666_667
        if nanoseconds > SurfaceCommitTargetTime.maximumNanosecondValue {
            seconds += 1
            nanoseconds -= SurfaceCommitTargetTime.maximumNanosecondValue + 1
        }

        return try SurfaceCommitTargetTime(seconds: seconds, nanoseconds: nanoseconds)
    }

    package static func canReuseRenderTarget(
        configuredGeometry: SurfaceGeometry?,
        requestedGeometry: SurfaceGeometry
    ) -> Bool {
        configuredGeometry == requestedGeometry
    }

    private func prepareForGeometryReconfiguration() throws(ManagedGPUPreviewBackingError) {
        do {
            try presenter.retireAvailableBuffers()
        } catch {
            throw .presentation(error)
        }
        explicitSynchronization?.destroy()
        explicitSynchronization = nil
        renderTarget = nil
        configuredGeometry = nil
        device = nil
    }

    private func surfaceFeedback(
        from capabilities: SurfaceCapabilitySnapshot
    ) throws(ManagedGPUPreviewBackingError) -> RawLinuxDmabufFeedbackSnapshot {
        guard case .surfaceFeedback(_, let feedback) = capabilities.dmabuf else {
            throw .setup(.surfaceFeedbackUnavailable)
        }

        return feedback.snapshot
    }

    private func selectFormat(
        from feedback: RawLinuxDmabufFeedbackSnapshot
    ) throws(ManagedGPUPreviewBackingError) -> GBMFormatModifierSelection {
        do {
            return try GBMFormatSelector.selectFormatModifier(
                from: feedback,
                policy: try GBMFormatSelectionPolicy(
                    preferredFormats: [
                        GBMDRMFormat.xrgb8888,
                        GBMDRMFormat.argb8888,
                    ]
                )
            )
        } catch {
            throw .setup(.noCompatibleFormat)
        }
    }

    private func createDevice(
        for selection: GBMFormatModifierSelection
    ) throws(ManagedGPUPreviewBackingError) -> GBMDevice {
        do {
            return try GBMDevice(
                adoptingRenderNodeFileDescriptor: DRMRenderNodeSelector.openRenderNode(
                    for: selection.targetDevice
                )
            )
        } catch {
            throw .setup(ManagedGPUPreviewBackingError.backingFailure(for: error))
        }
    }

    private func createRenderTarget(
        device: GBMDevice,
        formatModifier: RawLinuxDmabufFormatModifier,
        geometry: SurfaceGeometry
    ) throws(ManagedGPUPreviewBackingError) -> EGLGBMRenderTarget {
        do {
            let size = try GBMBufferSize(
                width: UInt32(geometry.bufferSize.width.rawValue),
                height: UInt32(geometry.bufferSize.height.rawValue)
            )
            return try EGLGBMRenderTarget(
                device: device,
                surfaceDescriptor: GBMSurfaceDescriptor(
                    size: size,
                    formatModifier: formatModifier
                )
            )
        } catch let error as EGLRenderError {
            throw .render(error)
        } catch let error as GBMAllocationError {
            throw .allocation(error)
        } catch {
            throw .setup(.eglUnavailable)
        }
    }

    private func nextSlotID() throws(ManagedGPUPreviewBackingError) -> GBMBufferPoolSlotID {
        do {
            let slotID = try GBMBufferPoolSlotID(nextSlotRawValue)
            nextSlotRawValue += 1
            return slotID
        } catch {
            throw .allocation(.invalidBufferDimensions(width: 0, height: 0))
        }
    }

    private func recordFailure(_ error: ManagedGPUPreviewBackingError) {
        recordFailure(error.failure)
    }

    private func recordFailure(_ failure: GPUBackingFailure) {
        if runtimePath == .empty, let capabilities {
            runtimePath = .afterFailure(capabilities: capabilities, failure: failure)
        } else {
            runtimePath = runtimePath.markingFailure(failure)
        }
    }

    private static func failure(
        for error: GraphicsPreviewSurfaceFeedbackError
    ) -> GPUBackingFailure {
        switch error {
        case .linuxDmabufUnavailable:
            .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            .surfaceFeedbackUnavailable
        case .runtime:
            .surfaceFeedbackUnavailable
        }
    }
}

package struct GPUClearColor: Equatable, Sendable {
    package let red: Float
    package let green: Float
    package let blue: Float
    package let alpha: Float

    package init(
        red colorRed: Float, green colorGreen: Float, blue colorBlue: Float, alpha colorAlpha: Float
    ) {
        red = colorRed
        green = colorGreen
        blue = colorBlue
        alpha = colorAlpha
    }
}
