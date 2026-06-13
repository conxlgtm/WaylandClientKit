import WaylandClient

extension WaylandGraphicsWindowBackingStorage {
    package static func isCommittedManagedGPUFrameFailure(_ error: any Error) -> Bool {
        error is CommittedManagedGPUFrameFailure
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
            .failed(.explicitSyncSetupFailed), .failed(.explicitSyncSubmissionFailed),
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
        WaylandGraphicsRuntimePath(
            capabilities: runtimePath.capabilities,
            backing: .failed(reason),
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
