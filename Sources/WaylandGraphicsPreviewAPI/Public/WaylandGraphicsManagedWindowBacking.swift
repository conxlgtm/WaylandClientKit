import WaylandClient
import WaylandGPUPreview

package protocol WaylandGraphicsManagedWindow: Sendable {
    var id: WindowID { get }
    var geometry: SurfaceGeometry { get async throws }
    var isClosed: Bool { get async throws }

    func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds: Int32
    ) async throws -> SurfaceGeometry

    func show(
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func redraw(
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func close() async
}

extension WaylandGraphicsManagedWindow {
    package func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceGeometry {
        try await geometry
    }
}

extension Window: WaylandGraphicsManagedWindow {}

package struct WaylandGraphicsManagedGPUClearFrameSubmission: Sendable {
    let color: GPUClearColor
    let metadata: SurfaceCommitMetadata
    let geometry: SurfaceGeometry
    let synchronization: GPUBufferSubmissionSynchronization
    let pacing: SurfacePacingConstraint
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
            synchronization: submission.synchronization,
            pacing: submission.pacing,
            requestPresentationFeedback: submission.requestPresentationFeedback
        )
    }
}
