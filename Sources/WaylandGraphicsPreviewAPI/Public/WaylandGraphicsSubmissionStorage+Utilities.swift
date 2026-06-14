import Glibc
import WaylandClient
import WaylandGPUPreview
import WaylandRaw

extension WaylandGraphicsWindowBackingStorage {
    package static func isCommittedManagedGPUFrameFailure(_ error: any Error) -> Bool {
        error is CommittedManagedGPUFrameFailure
    }

    package static func isCommittedExternalBufferFrameFailure(_ error: any Error) -> Bool {
        guard let presenterError = error as? GPUWindowPresenterError else { return false }
        return presenterError.committedFrameFailure != nil
    }

    package static func shouldRequestPresentationFeedback(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> Bool {
        switch configuration.presentationFeedbackPolicy {
        case .none:
            false
        case .requestWhenAvailable, .require:
            capabilities.presentationFeedback.isAvailable
        }
    }

    package static func explicitSyncBlocksSoftwareFallback(
        _ status: WaylandGraphicsRuntimeStatus
    ) -> Bool {
        switch status {
        case .configured, .active, .failed(.explicitSyncRequiredButUnavailable),
            .failed(.explicitSyncReleaseFailed):
            true
        case .unavailable, .pending, .advertised, .fallback, .failed:
            false
        }
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        backingUnavailable reason: WaylandGraphicsUnavailableReason
    ) -> WaylandGraphicsRuntimePath {
        Self.runtimePath(runtimePath, backing: .failed(reason))
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        backing: WaylandGraphicsRuntimeStatus
    ) -> WaylandGraphicsRuntimePath {
        WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: backing,
            dmabuf: runtimePath.dmabuf,
            surfaceFeedback: runtimePath.surfaceFeedback,
            renderNode: runtimePath.renderNode,
            gbm: runtimePath.gbm,
            egl: runtimePath.egl,
            dmabufImport: runtimePath.dmabufImport,
            bufferLifecycle: runtimePath.bufferLifecycle,
            explicitSync: runtimePath.explicitSync,
            pacing: runtimePath.pacing,
            metadata: runtimePath.metadata,
            presentationFeedback: runtimePath.presentationFeedback
        )
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        explicitSync: WaylandGraphicsRuntimeStatus
    ) -> WaylandGraphicsRuntimePath {
        WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: runtimePath.backing,
            dmabuf: runtimePath.dmabuf,
            surfaceFeedback: runtimePath.surfaceFeedback,
            renderNode: runtimePath.renderNode,
            gbm: runtimePath.gbm,
            egl: runtimePath.egl,
            dmabufImport: runtimePath.dmabufImport,
            bufferLifecycle: runtimePath.bufferLifecycle,
            explicitSync: explicitSync,
            pacing: runtimePath.pacing,
            metadata: runtimePath.metadata,
            presentationFeedback: runtimePath.presentationFeedback
        )
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        externalBufferBacking backing: WaylandGraphicsRuntimeStatus
    ) -> WaylandGraphicsRuntimePath {
        WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: backing,
            dmabuf: .active,
            surfaceFeedback: runtimePath.surfaceFeedback,
            renderNode: .unavailable,
            gbm: .unavailable,
            egl: .unavailable,
            dmabufImport: .active,
            bufferLifecycle: .active,
            explicitSync: runtimePath.explicitSync,
            pacing: runtimePath.pacing,
            metadata: runtimePath.metadata,
            presentationFeedback: runtimePath.presentationFeedback
        )
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        externalBufferFailure reason: WaylandGraphicsUnavailableReason
    ) -> WaylandGraphicsRuntimePath {
        WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: .failed(reason),
            dmabuf: runtimePath.dmabuf,
            surfaceFeedback: runtimePath.surfaceFeedback,
            renderNode: runtimePath.renderNode,
            gbm: runtimePath.gbm,
            egl: runtimePath.egl,
            dmabufImport: .failed(reason),
            bufferLifecycle: .failed(reason),
            explicitSync: runtimePath.explicitSync,
            pacing: runtimePath.pacing,
            metadata: runtimePath.metadata,
            presentationFeedback: runtimePath.presentationFeedback
        )
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        fallbackExplicitSyncIfNeeded reason: WaylandGraphicsFallbackReason
    ) -> WaylandGraphicsRuntimePath {
        switch reason {
        case .explicitSyncSetupFailed, .explicitSyncSubmissionFailed:
            Self.runtimePath(runtimePath, explicitSync: .fallback(reason))
        default:
            runtimePath
        }
    }

    package static func softwarePacingSelection(
        policy: GPUFramePacingPolicy,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        fifoBarrierPrimed: Bool
    ) throws -> GPUFramePacingPolicySelection {
        policy.selectConstraint(
            capability: SurfacePacingCapability(capabilities.framePacing),
            commitTimingTarget: try nextCommitTimingTarget(),
            fifoBarrierPrimed: fifoBarrierPrimed
        )
    }

    package static func runtimePath(
        _ runtimePath: WaylandGraphicsRuntimePath,
        pacingSelection: GPUFramePacingPolicySelection
    ) -> WaylandGraphicsRuntimePath {
        let pacing = WaylandGraphicsPacingStatus(
            fifo: Self.pacingStatus(
                runtimePath.pacing.fifo,
                selection: pacingSelection,
                fallbackReason: .fifoUnavailable,
                activeConstraint: pacingSelection.constraint.usesFIFO
            ),
            commitTiming: Self.pacingStatus(
                runtimePath.pacing.commitTiming,
                selection: pacingSelection,
                fallbackReason: .commitTimingUnavailable,
                activeConstraint: pacingSelection.constraint.usesCommitTiming
            )
        )
        return WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: runtimePath.backing,
            dmabuf: runtimePath.dmabuf,
            surfaceFeedback: runtimePath.surfaceFeedback,
            renderNode: runtimePath.renderNode,
            gbm: runtimePath.gbm,
            egl: runtimePath.egl,
            dmabufImport: runtimePath.dmabufImport,
            bufferLifecycle: runtimePath.bufferLifecycle,
            explicitSync: runtimePath.explicitSync,
            pacing: pacing,
            metadata: runtimePath.metadata,
            presentationFeedback: runtimePath.presentationFeedback
        )
    }

    private static func pacingStatus(
        _ current: WaylandGraphicsRuntimeStatus,
        selection: GPUFramePacingPolicySelection,
        fallbackReason: GPURuntimePathReason,
        activeConstraint: Bool
    ) -> WaylandGraphicsRuntimeStatus {
        if selection.fallbackReason == fallbackReason {
            return .fallback(WaylandGraphicsFallbackReason(fallbackReason))
        }
        return activeConstraint ? .active : current
    }

    private static func nextCommitTimingTarget()
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
}

extension SurfacePacingCapability {
    init(_ availability: WaylandGraphicsFramePacingAvailability) {
        switch (availability.fifo.version, availability.commitTiming.version) {
        case (.some(let fifo), .some(let commitTiming)):
            self = .fifoAndCommitTiming(
                fifo: RawVersion(fifo),
                commitTiming: RawVersion(commitTiming)
            )
        case (.some(let fifo), .none):
            self = .fifo(version: RawVersion(fifo))
        case (.none, .some(let commitTiming)):
            self = .commitTiming(version: RawVersion(commitTiming))
        case (.none, .none):
            self = .unavailable
        }
    }
}

extension SurfacePacingConstraint {
    var usesFIFO: Bool {
        switch self {
        case .fifo, .fifoAndTargetTime:
            true
        case .none, .targetTime:
            false
        }
    }

    var usesCommitTiming: Bool {
        switch self {
        case .targetTime, .fifoAndTargetTime:
            true
        case .none, .fifo:
            false
        }
    }
}

func clearSoftwareFrame(
    _ frame: borrowing SoftwareFrame,
    color: UInt32
) {
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            unsafe pixels[unchecked: index] = color
        }
    }
}
