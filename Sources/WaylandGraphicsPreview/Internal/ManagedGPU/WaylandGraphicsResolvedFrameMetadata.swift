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
    package var alpha: Bool
    package var colorRepresentation: Bool
    package var colorRepresentationPending: Bool
    package var colorDescription: Bool
    package var presentationHint: Bool

    package static let none = Self(
        contentType: false,
        alpha: false,
        colorRepresentation: false,
        colorRepresentationPending: false,
        colorDescription: false,
        presentationHint: false
    )

    package var isEmpty: Bool {
        !contentType
            && !alpha
            && !colorRepresentation
            && !colorRepresentationPending
            && !colorDescription
            && !presentationHint
    }

    package func applying(to path: WaylandGraphicsRuntimePath)
        -> WaylandGraphicsRuntimePath
    {
        let metadata = WaylandGraphicsMetadataStatus(
            contentType: contentType
                ? .fallback(.contentTypeUnavailable)
                : path.metadata.contentType,
            alphaModifier: alpha
                ? .fallback(.alphaModifierUnavailable)
                : path.metadata.alphaModifier,
            tearingControl: presentationHint
                ? .fallback(.presentationHintUnavailable)
                : path.metadata.tearingControl,
            colorRepresentation: colorRepresentationPending
                ? .fallback(.colorRepresentationSupportPending)
                : colorRepresentation
                    ? .fallback(.colorRepresentationUnavailable)
                    : path.metadata.colorRepresentation,
            colorManagement: colorDescription
                ? .fallback(.colorManagementUnavailable)
                : path.metadata.colorManagement
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
