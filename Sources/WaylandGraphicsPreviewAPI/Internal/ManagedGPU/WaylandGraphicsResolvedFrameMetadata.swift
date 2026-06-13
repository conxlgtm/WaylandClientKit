import WaylandClient

package struct WaylandGraphicsResolvedFrameMetadata: Equatable, Sendable {
    package var commitMetadata: SurfaceCommitMetadata
    package var fallbacks: WaylandGraphicsMetadataFallbacks

    package static let `default` = Self(
        commitMetadata: .default,
        fallbacks: .none
    )
}

package struct WaylandGraphicsMetadataFallbacks: Equatable, Sendable {
    package var contentType: Bool
    package var presentationHint: Bool

    package static let none = Self(contentType: false, presentationHint: false)

    package var isEmpty: Bool {
        !contentType && !presentationHint
    }

    package func applying(to path: WaylandGraphicsRuntimePath)
        -> WaylandGraphicsRuntimePath
    {
        let fallback = WaylandGraphicsRuntimeStatus.fallback(
            .metadataRequiredButUnavailable
        )
        let metadata = WaylandGraphicsMetadataStatus(
            contentType: contentType ? fallback : path.metadata.contentType,
            alphaModifier: path.metadata.alphaModifier,
            tearingControl: presentationHint
                ? fallback
                : path.metadata.tearingControl,
            colorRepresentation: path.metadata.colorRepresentation,
            colorManagement: path.metadata.colorManagement
        )

        return WaylandGraphicsRuntimePath(
            capabilities: path.capabilities,
            backing: path.backing,
            dmabuf: path.dmabuf,
            surfaceFeedback: path.surfaceFeedback,
            renderNode: path.renderNode,
            gbm: path.gbm,
            egl: path.egl,
            dmabufImport: path.dmabufImport,
            bufferLifecycle: path.bufferLifecycle,
            explicitSync: path.explicitSync,
            pacing: path.pacing,
            metadata: metadata,
            presentationFeedback: path.presentationFeedback
        )
    }
}
