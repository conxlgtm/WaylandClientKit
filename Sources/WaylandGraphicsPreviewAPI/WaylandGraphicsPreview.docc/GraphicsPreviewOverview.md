# Graphics Preview Overview

`WaylandGraphicsPreview` is a renderer-neutral, source-breaking preview product
for graphics-backed Wayland windows. It lets public users request software
backing or managed GPU clear-frame presentation, then inspect typed runtime-path
facts. Package-scoped external-buffer submission remains preview evidence for
renderer-owned dmabuf presentation without exposing raw graphics handles as
public API.

## What It Is

The preview API wraps a public ``WaylandGraphicsWindowBacking`` around a
`Window`. Applications lease a frame, inspect the frame contract, submit clear
frames or software drawing work, and receive typed runtime-path facts.

Package-scoped external-buffer helpers are intentionally narrow. They register
move-only descriptors, commit reserved buffers, track compositor release, and
return a package-scoped receipt for each submitted use. The renderer helper keeps
each GPU allocation alive until the corresponding receipt reaches a terminal
release result.

## Choosing Backing

Use ``WaylandGraphicsConfiguration`` to request:

- `WaylandGraphicsPresentationMode.software` for software-only backing.
- `WaylandGraphicsPresentationMode.managedGPU` for managed GPU clear-frame
  attempts.
- `WaylandGraphicsPresentationMode.externalGPU` for renderer-owned external
  buffers.

Use ``WaylandGraphicsFallbackPolicy`` to choose whether GPU failures may fall
back to software or must throw a typed ``WaylandGraphicsError``.

## Current External Buffer Scope

- One-to-four-plane XRGB8888 or ARGB8888 images.
- Package-scoped move-only descriptors whose file-descriptor transfer plumbing
  stays out of public graphics API.
- Persistent registration and release-gated reservation.
- Package-scoped implicit synchronization and DRM syncobj explicit
  synchronization.
- Release-gated reuse through package-scoped submission receipts.

## Example

See `GPUPreviewSmokeClient` in `Examples/GPUPreviewSmokeClient`,
`GraphicsPreviewManagedGPUClear` in `Examples/GraphicsPreviewManagedGPUClear`,
and `GraphicsPreviewExternalBufferSmoke` in
`Examples/GraphicsPreviewExternalBufferSmoke`.
