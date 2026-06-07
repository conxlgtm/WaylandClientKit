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
        case .commitTimingRejected, .commitFailed, .presentationTrackingFailed:
            .compositorRejectedBuffer
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

// swiftlint:disable:next type_body_length
package final class ManagedGPUPreviewBacking {
    private let window: Window
    private let presenter = GPUWindowPresenter()
    private var device: GBMDevice?
    private var renderTarget: EGLGBMRenderTarget?
    private var capabilities: SurfaceCapabilitySnapshot?
    private var runtimePath = GPURuntimePathSnapshot.empty
    private var nextSlotRawValue = 0
    private var isClosed = false

    package init(window backingWindow: Window) {
        window = backingWindow
    }

    package var runtimePathSnapshot: GPURuntimePathSnapshot {
        presenter.runtimePathSnapshot == .empty ? runtimePath : presenter.runtimePathSnapshot
    }

    package var surfaceCapabilities: SurfaceCapabilitySnapshot? {
        capabilities
    }

    package func close() {
        isClosed = true
        presenter.retireAll(reason: .windowClosed)
        renderTarget?.destroy()
        renderTarget = nil
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
        guard renderTarget == nil else {
            return
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
        runtimePath = .afterEGLTargetSetup(capabilities: surfaceCapabilities)
    }

    @discardableResult
    package func submitClearFrame(
        color: GPUClearColor,
        metadata: SurfaceCommitMetadata,
        geometry: SurfaceGeometry,
        synchronization: GPUBufferSubmissionSynchronization = .implicit,
        pacing: SurfacePacingConstraint = .none
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

        do {
            try GPUBackingRequirements(
                synchronization: synchronization,
                pacing: pacing,
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
                metadata: metadata,
                synchronization: synchronization,
                pacing: pacing
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
        metadata: SurfaceCommitMetadata,
        synchronization: GPUBufferSubmissionSynchronization,
        pacing: SurfacePacingConstraint
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        do {
            let slotID = try nextSlotID()
            try presenter.installBuffer(
                ManagedGPUPreviewBuffer(
                    buffer: imported.buffer,
                    lockedBuffer: imported.lockedBuffer
                ),
                slotID: slotID
            )
            return try await presenter.presentSlot(
                slotID,
                submit: { [window] buffer, submitConstraints, commitMetadata in
                    try await window.presentGraphicsPreviewBuffer(
                        buffer,
                        submitConstraints: submitConstraints,
                        metadata: commitMetadata
                    )
                },
                synchronization: synchronization,
                pacing: pacing,
                metadata: metadata
            )
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

private final class ManagedGPUPreviewBuffer: GPUWindowPresenterBuffer {
    private let buffer: RawLinuxDmabufBuffer
    private var lockedBuffer: GBMLockedSurfaceBuffer?
    private var releaseObserver: (() -> Void)?

    init(
        buffer importedBuffer: RawLinuxDmabufBuffer,
        lockedBuffer importedLockedBuffer: GBMLockedSurfaceBuffer
    ) {
        buffer = importedBuffer
        lockedBuffer = importedLockedBuffer
    }

    var surfaceBuffer: RawSurfaceBuffer {
        buffer.surfaceBuffer
    }

    func setReleaseObserver(_ observer: @escaping () -> Void) {
        releaseObserver = observer
        buffer.setReleaseObserver { [weak self] in
            self?.handleRelease()
        }
    }

    func destroy() {
        releaseObserver = nil
        lockedBuffer?.release()
        lockedBuffer = nil
        buffer.destroy()
    }

    deinit {
        destroy()
    }

    private func handleRelease() {
        lockedBuffer?.release()
        lockedBuffer = nil
        releaseObserver?()
    }
}
