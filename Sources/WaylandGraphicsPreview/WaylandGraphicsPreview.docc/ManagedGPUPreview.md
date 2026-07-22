# Managed GPU Preview

Managed GPU preview is package-internal GPU setup exposed only through typed
public facts. The public product can request the path and observe the result,
but cannot access GBM, EGL, DRM, dmabuf, syncobj, file descriptors, or raw
Wayland proxies.

## Setup Path

Managed GPU setup covers surface dmabuf feedback, format and render-node
selection, GBM/EGL setup, dmabuf import, commit, and buffer reuse. Requested
linux-drm-syncobj, FIFO, commit-timing, and metadata objects are installed before
the frame commit when available.

Display-level dmabuf advertisement is only a prerequisite. Surface feedback and
successful submission are required before public runtime facts report active
GPU.

The compositor matrix records live evidence. Commit timing has typed fallback
and failure states but no active live evidence yet.

## Policy

Policy values control synchronization, pacing, metadata, and presentation
feedback. ``WaylandGraphicsFrameSchedule`` can override them for one frame.

`implicitOnly` avoids explicit sync. `preferExplicit` falls back with a runtime
reason if setup fails before explicit synchronization reaches the surface. Once
installed, implicit software fallback is unavailable. `requireExplicit` fails
instead of falling back.

`preferFIFO` and `preferCommitTiming` apply available submit constraints to GPU,
software, and fallback commits. Missing protocols produce fallback facts;
rejected timestamps produce typed failures. FIFO uses a priming commit, then
waits on the previous barrier while setting the next.

`preferAvailable` applies supported content type, presentation hint, alpha, and
color representation metadata. Color-description attachment awaits a managed
image-description producer.

Unsupported or unavailable requirements are reported as typed
`WaylandGraphicsError` values or fallback reasons according to
``WaylandGraphicsPresentationPolicy``.

## Evidence

Managed GPU support is compositor-sensitive. Use
`swift run --package-path Examples GPUPreviewSmokeClient` or `swift run GraphicsPreviewManagedGPUClear`
under a real compositor and record the printed runtime path in
`docs/compositor-matrix.md`.

```bash
swift run --package-path Examples GPUPreviewSmokeClient -- --sync prefer-explicit --pacing fifo
swift run GraphicsPreviewManagedGPUClear -- --sync prefer-explicit --pacing fifo --metadata prefer --content-type game --presentation-hint async --auto-close --print-summary
```

An active matrix entry needs a submitted frame whose runtime path reports
`active`. Commit timing still needs that evidence from an advertising compositor.
