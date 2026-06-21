# Graphics Preview Overview

`WaylandGraphicsPreview` is a renderer-neutral, source-breaking preview product
for graphics-backed Wayland windows. It lets public users request software
backing, managed GPU clear-frame presentation, or renderer-owned external-buffer
presentation, then inspect typed runtime-path facts.

## What It Is

The preview API wraps a public ``WaylandGraphicsWindowBacking`` around a
`Window`. Applications lease a frame, inspect the frame contract, submit clear
frames, software drawing work, or one-to-four-plane external buffers, and receive
typed runtime-path facts.

External-buffer submission is intentionally narrow. WCK registers move-only
descriptors, commits reserved buffers, tracks compositor release, and returns a
``WaylandGraphicsExternalBufferSubmissionReceipt`` for each submitted use. The
renderer keeps each GPU allocation alive until the corresponding receipt reaches
a terminal release result.

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
- Move-only descriptors whose file-descriptor transfer plumbing stays out of
  public graphics API.
- Persistent registration and release-gated reservation.
- Implicit synchronization and DRM syncobj explicit synchronization.
- Release-gated reuse through ``WaylandGraphicsExternalBufferSubmissionReceipt``.

## Example

See `GPUPreviewSmokeClient` in `Examples/GPUPreviewSmokeClient`,
`GraphicsPreviewManagedGPUClear` in `Examples/GraphicsPreviewManagedGPUClear`,
and `GraphicsPreviewExternalBufferSmoke` in
`Examples/GraphicsPreviewExternalBufferSmoke`.
