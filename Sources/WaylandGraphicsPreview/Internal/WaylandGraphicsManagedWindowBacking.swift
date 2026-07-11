import WaylandClient
import WaylandGPUPreview
import WaylandRaw

package protocol WaylandGraphicsManagedWindow: Sendable {
    var id: WindowID { get }
    var geometry: SurfaceGeometry { get async throws }
    var isClosed: Bool { get async throws }

    func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds: Int32
    ) async throws -> SurfaceGeometry

    func requestGraphicsPreviewSurfaceFeedback(
        timeoutMilliseconds: Int32
    ) async throws -> SurfaceCapabilitySnapshot

    // swiftlint:disable:next function_parameter_count
    func show(
        timeoutMilliseconds: Int32,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func redraw(
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func importGraphicsPreviewSynchronizationTimeline(
        _ fileDescriptor: inout RawDrmSyncobjTimelineFD,
        identity: SurfaceSyncTimelineIdentity
    ) async throws

    func removeGraphicsPreviewSynchronizationTimeline(
        identity: SurfaceSyncTimelineIdentity
    ) async throws

    func importGraphicsPreviewExternalBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor
    ) async throws -> RawLinuxDmabufBuffer

    func presentGraphicsPreviewBuffer(
        _ buffer: RawSurfaceBuffer,
        submitConstraints: SurfaceSubmitConstraints,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        presentationFeedbackHandler:
            (@Sendable (SurfacePresentationFeedback) -> Void)?
    ) async throws -> PreviewBufferPresentationResult

    func close() async
}

extension WaylandGraphicsManagedWindow {
    package func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceGeometry {
        try await geometry
    }

    package func requestGraphicsPreviewSurfaceFeedback(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceCapabilitySnapshot {
        throw GraphicsPreviewSurfaceFeedbackError.surfaceFeedbackUnavailable
    }

    package func importGraphicsPreviewSynchronizationTimeline(
        _ fileDescriptor: inout RawDrmSyncobjTimelineFD,
        identity _: SurfaceSyncTimelineIdentity
    ) async throws {
        fileDescriptor.close()
        throw SurfaceSubmitConstraintError.explicitSyncUnavailable
    }

    package func removeGraphicsPreviewSynchronizationTimeline(
        identity _: SurfaceSyncTimelineIdentity
    ) async throws {
        // No imported timeline exists for the default non-explicit-sync window.
    }

    package func importGraphicsPreviewExternalBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor
    ) async throws -> RawLinuxDmabufBuffer {
        var descriptor = descriptor
        do {
            try descriptor.closeFileDescriptors()
        } catch {
            _ = error
        }
        throw WaylandGraphicsError.unavailable(.dmabufUnavailable)
    }

    package func presentGraphicsPreviewBuffer(
        _: RawSurfaceBuffer,
        submitConstraints _: SurfaceSubmitConstraints,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        presentationFeedbackHandler _: (@Sendable (SurfacePresentationFeedback) -> Void)?
    ) async throws -> PreviewBufferPresentationResult {
        throw WaylandGraphicsError.unavailable(.managedGPUSubmissionUnavailable)
    }
}

extension Window: WaylandGraphicsManagedWindow {
    package func importGraphicsPreviewExternalBuffer(
        _ descriptor: consuming WaylandGraphicsExternalBufferDescriptor
    ) async throws -> RawLinuxDmabufBuffer {
        var descriptor = descriptor
        let importPlan = try descriptor.makeImportPlan()
        return try await withGraphicsPreviewLinuxDmabuf { linuxDmabuf, syncDisplay in
            try importPlan.importBuffer(
                using: linuxDmabuf,
                timeoutMilliseconds: WaylandDisplay.defaultDiscoveryTimeoutMilliseconds,
                syncDisplay: syncDisplay
            )
        }
    }
}

package struct WaylandGraphicsManagedGPUClearFrameSubmission: Sendable {
    let color: GPUClearColor
    let metadata: SurfaceCommitMetadata
    let geometry: SurfaceGeometry
    let synchronizationPolicy: GPUSynchronizationPolicy
    let pacingPolicy: GPUFramePacingPolicy
    let requestPresentationFeedback: Bool
}

package protocol WaylandGraphicsManagedGPUBacking: AnyObject {
    var runtimePathSnapshot: GPURuntimePathSnapshot { get }
    var surfaceCapabilities: SurfaceCapabilitySnapshot? { get }

    func close()

    func submitClearFrame(
        _ submission: WaylandGraphicsManagedGPUClearFrameSubmission
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame
}

extension ManagedGPUPreviewBacking: WaylandGraphicsManagedGPUBacking {
    package func submitClearFrame(
        _ submission: WaylandGraphicsManagedGPUClearFrameSubmission
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        try await submitClearFrame(
            color: submission.color,
            metadata: submission.metadata,
            geometry: submission.geometry,
            synchronizationPolicy: submission.synchronizationPolicy,
            pacingPolicy: submission.pacingPolicy,
            requestPresentationFeedback: submission.requestPresentationFeedback
        )
    }
}
