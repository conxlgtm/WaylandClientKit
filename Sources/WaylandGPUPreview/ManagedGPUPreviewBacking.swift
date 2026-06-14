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
    case committedFrame(GPUBackingFailure)
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
        case .committedFrame(let failure):
            failure
        case .closed:
            .commitFailed
        }
    }

    package var committedFrameWasPresented: Bool {
        switch self {
        case .committedFrame:
            true
        case .setup, .render, .allocation, .dmabufImport, .runtime, .presentation, .closed:
            false
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
        case .explicitSyncSetupFailed:
            .explicitSyncSetupFailed
        case .explicitSyncSubmissionFailed:
            .explicitSyncSubmissionFailed
        case .explicitSyncReleaseFailed:
            .explicitSyncReleaseFailed
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
        case .committedFrame(let failure):
            "managed GPU frame committed before \(failure.description)"
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
        case .syncobjCreationFailed, .syncobjFileDescriptorExportFailed:
            .explicitSyncSetupFailed
        case .syncobjTimelineSignalFailed:
            .explicitSyncSubmissionFailed
        case .syncobjTimelineWaitFailed:
            .explicitSyncReleaseFailed
        }
    }

    package static func backingFailure(for error: GPUWindowPresenterError) -> GPUBackingFailure {
        switch error {
        case .submitConstraints:
            .submitConstraintRejected
        case .metadata(let metadataError):
            .metadataRequiredButUnavailable(metadataError)
        case .committedFrame(let failure):
            failure
        case .missingBuffer, .state, .releaseFailure:
            .gbmAllocationFailed
        case .window:
            .commitFailed
        }
    }
}

package final class ManagedGPUPreviewBacking {
    let window: Window
    let presenter = GPUWindowPresenter()
    var device: GBMDevice?
    var renderTarget: EGLGBMRenderTarget?
    var explicitSynchronization: ManagedGPUExplicitSynchronization?
    var retainedExplicitSynchronizations: [RetainedExplicitSynchronization] = []
    var configuredGeometry: SurfaceGeometry?
    var capabilities: SurfaceCapabilitySnapshot?
    var runtimePath = GPURuntimePathSnapshot.empty
    var nextSlotRawValue = 0
    var nextSyncTimelineRawValue: UInt64 = 1
    var isClosed = false

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
        destroyRetainedExplicitSynchronizations()
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
        let context = try await prepareClearFrameSubmission(
            metadata: metadata,
            geometry: geometry,
            synchronizationPolicy: synchronizationPolicy,
            pacingPolicy: pacingPolicy,
            requestPresentationFeedback: requestPresentationFeedback
        )
        try reapExplicitReleaseSignalsIfAvailable()

        let imported: (buffer: RawLinuxDmabufBuffer, lockedBuffer: GBMLockedSurfaceBuffer)
        do {
            imported = try await renderAndImportBuffer(
                renderTarget: context.renderTarget,
                color: color
            )
        } catch let error {
            recordFailure(error)
            throw error
        }
        runtimePath = .afterDmabufImportSetup(capabilities: context.capabilities)
        do {
            return try await presentImportedBuffer(
                imported,
                renderTarget: context.renderTarget,
                options: context.options
            )
        } catch let error {
            recordFailure(error)
            throw error
        }
    }
}

struct RetainedExplicitSynchronization {
    let synchronization: ManagedGPUExplicitSynchronization
    // Keep the DRM file descriptor backing the syncobj timeline alive.
    let device: GBMDevice?
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
