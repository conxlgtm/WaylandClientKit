# Managed GPU Preview

Managed GPU preview is package-internal GPU setup exposed only through typed
public facts. The public product can request the path and observe the result,
but cannot access GBM, EGL, DRM, dmabuf, syncobj, file descriptors, or raw
Wayland proxies.

## Setup Path

For managed GPU backing, WaylandClientKit attempts surface-specific dmabuf feedback,
format/modifier selection, render-node selection, GBM device and render target
creation, EGL clear rendering, dmabuf import, owner-thread surface commit, and
buffer release/reuse tracking. When requested and available, the commit path
also installs linux-drm-syncobj, FIFO, commit-timing, and metadata protocol
objects before applying the frame commit.

Display-level dmabuf advertisement is only a prerequisite. Surface feedback and
successful submission are required before public runtime facts report active
GPU.

The current compositor matrix proves active managed GPU clear-frame submission,
explicit synchronization, FIFO pacing, content-type metadata, and
presentation-hint/tearing metadata. Commit timing is implemented and reports
typed fallback/failure states, but it is not yet live-proven active.

## Policy

`WaylandGraphicsSynchronizationPolicy` controls explicit-sync requirements.
`WaylandGraphicsPacingPolicy` controls preview frame-pacing requirements.
`WaylandGraphicsMetadataPolicy` controls whether surface metadata is allowed.
`WaylandGraphicsPresentationFeedbackPolicy` controls whether presentation
feedback is requested or required.

`WaylandGraphicsSynchronizationPolicy.implicitOnly` never creates explicit sync
objects. `WaylandGraphicsSynchronizationPolicy.preferExplicit` attempts explicit
sync and falls back to implicit synchronization with a runtime fallback reason
when the compositor or setup path cannot provide it before explicit
synchronization is installed on the surface. Once the surface is explicitly
synchronized, implicit software fallback is rejected with a typed unavailable
reason.
`WaylandGraphicsSynchronizationPolicy.requireExplicit` never silently falls back.

`WaylandGraphicsPacingPolicy.preferFIFO` and
`WaylandGraphicsPacingPolicy.preferCommitTiming` apply submit constraints
when their protocols are available. The same pacing policy is carried into
direct software commits and allowed software fallback commits. Missing protocols
become pacing fallback facts; rejected commit-timing timestamps become typed
failures. The preview commit-timing path uses an internal target time until a
public scheduling API is designed.
FIFO pacing uses a priming commit before waits: the first FIFO-paced frame sets
a barrier, and later FIFO-paced frames wait on the previous barrier while
setting the next one.

`WaylandGraphicsMetadataPolicy.preferAvailable` allows public content type
and presentation-hint metadata to be applied when the compositor supports the
matching protocols. Color representation, color-management, and alpha facts
remain package-internal runtime facts rather than renderer policy.

Unsupported or unavailable requirements are reported as typed
`WaylandGraphicsError` values or fallback reasons according to
`WaylandGraphicsFallbackPolicy`.

## Evidence

Managed GPU support is compositor-sensitive. Use
`swift run GPUPreviewSmokeClient` or `swift run GraphicsPreviewManagedGPUClear`
under a real compositor and record the printed runtime path in
`docs/compositor-matrix.md`.

Examples:

```bash
swift run GPUPreviewSmokeClient -- --sync prefer-explicit --pacing fifo
swift run GraphicsPreviewManagedGPUClear -- --sync prefer-explicit --pacing fifo --metadata prefer --content-type game --presentation-hint async --auto-close --print-summary
```

Do not record explicit synchronization, FIFO, commit timing, or metadata as
active unless the runtime-path output itself reports `active` for that
component on a submitted frame. Current KDE/KWin evidence records explicit
sync, FIFO, and metadata as active; commit timing still needs active
runtime-path evidence on a compositor that advertises it.
