import WaylandClient
import WaylandGraphicsCore
import WaylandRaw

extension ManagedGPUPreviewBacking {
    package static func canReuseRenderTarget(
        configuredGeometry: SurfaceGeometry?,
        requestedGeometry: SurfaceGeometry
    ) -> Bool {
        configuredGeometry == requestedGeometry
    }

    func prepareForGeometryReconfiguration() throws(ManagedGPUPreviewBackingError) {
        do {
            try presenter.retireAvailableBuffers()
        } catch {
            throw .presentation(error)
        }
        renderTarget = nil
        configuredGeometry = nil
        retainExplicitSynchronizationForOutstandingSubmissions()
        destroyUnusedRetainedExplicitSynchronizations()
    }

    func retainExplicitSynchronizationForOutstandingSubmissions() {
        guard let synchronization = explicitSynchronization else {
            device = nil
            return
        }

        explicitSynchronization = nil
        let explicitSubmissionStates = presenter.explicitSubmissionStates
        if synchronization.hasOutstandingReleaseTimeline(in: explicitSubmissionStates) {
            retainedExplicitSynchronizations.append(
                RetainedExplicitSynchronization(
                    synchronization: synchronization,
                    device: device
                )
            )
            device = nil
        } else {
            synchronization.destroy()
            device = nil
        }
    }

    func destroyUnusedRetainedExplicitSynchronizations() {
        let explicitSubmissionStates = presenter.explicitSubmissionStates
        var retainedSynchronizations: [RetainedExplicitSynchronization] = []

        for retained in retainedExplicitSynchronizations {
            if retained.synchronization.hasOutstandingReleaseTimeline(in: explicitSubmissionStates)
            {
                retainedSynchronizations.append(
                    RetainedExplicitSynchronization(
                        synchronization: retained.synchronization,
                        device: retained.device
                    )
                )
            } else {
                retained.synchronization.destroy()
            }
        }

        retainedExplicitSynchronizations = retainedSynchronizations
    }

    func destroyRetainedExplicitSynchronizations() {
        for retained in retainedExplicitSynchronizations {
            retained.synchronization.destroy()
        }
        retainedExplicitSynchronizations.removeAll()
    }

    func surfaceFeedback(
        from capabilities: SurfaceCapabilitySnapshot
    ) throws(ManagedGPUPreviewBackingError) -> RawLinuxDmabufFeedbackSnapshot {
        guard case .surfaceFeedback(_, let feedback) = capabilities.dmabuf else {
            throw .setup(.surfaceFeedbackUnavailable)
        }

        return feedback.snapshot
    }

    func selectFormat(
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
    func createDevice(
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

    func createRenderTarget(
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

    func nextSlotID() throws(ManagedGPUPreviewBackingError) -> GBMBufferPoolSlotID {
        do {
            let slotID = try GBMBufferPoolSlotID(nextSlotRawValue)
            nextSlotRawValue += 1
            return slotID
        } catch {
            throw .allocation(.invalidBufferDimensions(width: 0, height: 0))
        }
    }

    func recordFailure(_ error: ManagedGPUPreviewBackingError) {
        recordFailure(error.failure)
    }

    func recordFailure(_ failure: GPUBackingFailure) {
        if runtimePath == .empty, let capabilities {
            runtimePath = .afterFailure(capabilities: capabilities, failure: failure)
        } else {
            runtimePath = runtimePath.markingFailure(failure)
        }
    }

    static func failure(
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
