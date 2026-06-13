import WaylandClient
import WaylandGPUPreview

extension WaylandGraphicsRuntimePath {
    package init(
        gpuSnapshot: GPURuntimePathSnapshot,
        capabilities: SurfaceCapabilitySnapshot,
        backing: WaylandGraphicsRuntimeStatus
    ) {
        let publicCapabilities = WaylandGraphicsSurfaceCapabilities(
            snapshot: GraphicsPreviewSurfaceCapabilitySnapshot(snapshot: capabilities)
        )

        self.init(
            capabilities: publicCapabilities,
            backing: backing,
            dmabuf: Self.status(from: gpuSnapshot.dmabuf),
            surfaceFeedback: Self.status(from: gpuSnapshot.surfaceFeedback),
            renderNode: Self.status(from: gpuSnapshot.renderNode),
            gbm: Self.status(from: gpuSnapshot.gbm),
            egl: Self.status(from: gpuSnapshot.egl),
            dmabufImport: Self.status(from: gpuSnapshot.dmabufImport),
            bufferLifecycle: Self.status(from: gpuSnapshot.bufferLifecycle),
            explicitSync: Self.status(
                from: gpuSnapshot.synchronization,
                capabilities: publicCapabilities
            ),
            pacing: Self.status(
                from: gpuSnapshot.pacing,
                capabilities: publicCapabilities
            ),
            metadata: WaylandGraphicsMetadataStatus(
                contentType: Self.status(from: gpuSnapshot.contentType),
                alphaModifier: Self.status(from: gpuSnapshot.alpha),
                tearingControl: Self.status(from: gpuSnapshot.tearingControl),
                colorRepresentation: Self.status(
                    from: gpuSnapshot.colorRepresentation
                ),
                colorManagement: Self.status(from: gpuSnapshot.colorManagement)
            ),
            presentationFeedback: Self.status(
                from: gpuSnapshot.presentationFeedback
            )
        )
    }

    package static func status(
        from status: RuntimePathStatus
    ) -> WaylandGraphicsRuntimeStatus {
        switch status {
        case .unavailable:
            .unavailable
        case .advertised:
            .advertised
        case .configured:
            .configured
        case .active:
            .active
        case .fallback(let reason):
            .fallback(WaylandGraphicsFallbackReason(reason))
        case .failed(let failure):
            .failed(WaylandGraphicsUnavailableReason(failure))
        }
    }

    private static func status(
        from status: GPUSynchronizationRuntimeStatus,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> WaylandGraphicsRuntimeStatus {
        switch status {
        case .implicit:
            return protocolStatus(capabilities.explicitSync)
        case .explicitAdvertised:
            return .advertised
        case .explicitConfigured:
            return .configured
        case .explicitActive:
            return .active
        case .explicitFallback(let reason):
            return .fallback(WaylandGraphicsFallbackReason(reason))
        case .explicitFailed(let reason):
            return .failed(WaylandGraphicsUnavailableReason(reason))
        }
    }

    private static func status(
        from status: GPUFramePacingRuntimeStatus,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> WaylandGraphicsPacingStatus {
        switch status {
        case .none:
            return WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            )
        case .fifoAdvertised:
            return WaylandGraphicsPacingStatus(
                fifo: .advertised,
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            )
        case .commitTimingAdvertised:
            return WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: .advertised
            )
        case .fifoAndCommitTimingAdvertised:
            return WaylandGraphicsPacingStatus(
                fifo: .advertised,
                commitTiming: .advertised
            )
        case .fifoActive:
            return WaylandGraphicsPacingStatus(
                fifo: .active,
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            )
        case .commitTimingActive:
            return WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: .active
            )
        case .fifoAndCommitTimingActive:
            return WaylandGraphicsPacingStatus(fifo: .active, commitTiming: .active)
        case .fallback(let reason):
            return pacingFallbackStatus(
                reason,
                capabilities: capabilities
            )
        case .failed(let reason):
            return pacingFailureStatus(
                reason,
                capabilities: capabilities
            )
        }
    }

    private static func pacingFallbackStatus(
        _ reason: GPURuntimePathReason,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> WaylandGraphicsPacingStatus {
        let fallback = WaylandGraphicsRuntimeStatus.fallback(
            WaylandGraphicsFallbackReason(reason)
        )
        switch reason {
        case .fifoUnavailable:
            return WaylandGraphicsPacingStatus(
                fifo: fallback,
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            )
        case .commitTimingUnavailable, .commitTimingRejected:
            return WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: fallback
            )
        default:
            return WaylandGraphicsPacingStatus(fifo: fallback, commitTiming: fallback)
        }
    }

    private static func pacingFailureStatus(
        _ reason: GPURuntimePathReason,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> WaylandGraphicsPacingStatus {
        let failed = WaylandGraphicsRuntimeStatus.failed(
            WaylandGraphicsUnavailableReason(reason)
        )
        switch reason {
        case .fifoUnavailable:
            return WaylandGraphicsPacingStatus(
                fifo: failed,
                commitTiming: protocolStatus(capabilities.framePacing.commitTiming)
            )
        case .commitTimingUnavailable, .commitTimingRejected:
            return WaylandGraphicsPacingStatus(
                fifo: protocolStatus(capabilities.framePacing.fifo),
                commitTiming: failed
            )
        default:
            return WaylandGraphicsPacingStatus(fifo: failed, commitTiming: failed)
        }
    }

    private static func status(
        from status: SurfaceCapabilityStatus
    ) -> WaylandGraphicsRuntimeStatus {
        switch status {
        case .available:
            .advertised
        case .unavailable:
            .unavailable
        }
    }

    private static func protocolStatus(
        _ availability: WaylandGraphicsProtocolAvailability
    ) -> WaylandGraphicsRuntimeStatus {
        switch availability {
        case .unavailable:
            .unavailable
        case .pending:
            .pending
        case .available:
            .advertised
        }
    }
}

extension WaylandGraphicsFallbackReason {
    package init(_ reason: GPUFallbackReason) {
        self = Self(GPURuntimePathReason(reason))
    }

    // swiftlint:disable:next cyclomatic_complexity
    package init(_ reason: GPURuntimePathReason) {
        switch reason {
        case .policyForcedSHM:
            self = .forcedSoftware
        case .dmabufUnavailable:
            self = .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            self = .surfaceFeedbackUnavailable
        case .noCompatibleFormat:
            self = .noCompatibleFormat
        case .noRenderNode:
            self = .noRenderNode
        case .gbmUnavailable:
            self = .gbmUnavailable
        case .gbmAllocationFailed:
            self = .gbmAllocationFailed
        case .eglUnavailable:
            self = .eglUnavailable
        case .explicitSynchronizationUnavailable,
            .explicitSynchronizationNotConfigured:
            self = .explicitSyncRequiredButUnavailable
        case .contentTypeUnavailable,
            .alphaModifierUnavailable,
            .colorRepresentationUnavailable,
            .colorRepresentationSupportPending,
            .colorManagementUnavailable,
            .presentationHintUnavailable:
            self = .metadataRequiredButUnavailable
        case .compositorRejectedBuffer:
            self = .compositorRejectedBuffer
        case .fifoUnavailable:
            self = .fifoUnavailable
        case .commitTimingUnavailable:
            self = .commitTimingUnavailable
        case .commitTimingRejected:
            self = .commitTimingRejected
        case .commitFailed:
            self = .commitFailed
        case .presentationTrackingFailed:
            self = .presentationTrackingFailed
        }
    }
}

extension WaylandGraphicsUnavailableReason {
    package init(_ failure: GPUBackingFailure) {
        self = Self(GPURuntimePathReason(failure))
    }

    // swiftlint:disable:next cyclomatic_complexity
    package init(_ reason: GPURuntimePathReason) {
        switch reason {
        case .policyForcedSHM:
            self = .managedGPUSubmissionUnavailable
        case .dmabufUnavailable:
            self = .dmabufUnavailable
        case .surfaceFeedbackUnavailable:
            self = .surfaceFeedbackUnavailable
        case .noCompatibleFormat:
            self = .noCompatibleFormat
        case .noRenderNode:
            self = .noRenderNode
        case .gbmUnavailable:
            self = .gbmUnavailable
        case .gbmAllocationFailed:
            self = .gbmAllocationFailed
        case .eglUnavailable:
            self = .eglUnavailable
        case .explicitSynchronizationUnavailable,
            .explicitSynchronizationNotConfigured:
            self = .explicitSyncRequiredButUnavailable
        case .contentTypeUnavailable,
            .alphaModifierUnavailable,
            .colorRepresentationUnavailable,
            .colorRepresentationSupportPending,
            .colorManagementUnavailable,
            .presentationHintUnavailable:
            self = .metadataRequiredButUnavailable
        case .compositorRejectedBuffer:
            self = .compositorRejectedBuffer
        case .fifoUnavailable:
            self = .fifoUnavailable
        case .commitTimingUnavailable:
            self = .commitTimingUnavailable
        case .commitTimingRejected:
            self = .commitTimingRejected
        case .commitFailed:
            self = .commitFailed
        case .presentationTrackingFailed:
            self = .presentationTrackingFailed
        }
    }
}
