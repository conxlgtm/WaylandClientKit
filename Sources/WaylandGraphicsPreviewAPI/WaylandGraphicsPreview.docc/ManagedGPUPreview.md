# Managed GPU Preview

Managed GPU preview is package-internal GPU setup exposed only through typed
public facts. The public product can request the path and observe the result,
but cannot access GBM, EGL, DRM, dmabuf, syncobj, file descriptors, or raw
Wayland proxies.

## Setup Path

For managed GPU backing, SwiftWayland attempts surface-specific dmabuf feedback,
format/modifier selection, render-node selection, GBM device and render target
creation, EGL clear rendering, dmabuf import, owner-thread surface commit, and
buffer release/reuse tracking.

Display-level dmabuf advertisement is only a prerequisite. Surface feedback and
successful submission are required before public runtime facts report active
GPU.

## Policy

``WaylandGraphicsSynchronizationPolicy`` controls explicit-sync requirements.
``WaylandGraphicsPacingPolicy`` controls preview frame-pacing requirements.
``WaylandGraphicsMetadataPolicy`` controls whether surface metadata is allowed.
``WaylandGraphicsPresentationFeedbackPolicy`` controls whether presentation
feedback is requested or required.

Unsupported or unavailable requirements are reported as typed
``WaylandGraphicsError`` values or fallback reasons according to
``WaylandGraphicsFallbackPolicy``.

## Evidence

Managed GPU support is compositor-sensitive. Use
`swift run GPUPreviewSmokeClient` or `swift run GraphicsPreviewManagedGPUClear`
under a real compositor and record the printed runtime path in
`docs/compositor-matrix.md`.

