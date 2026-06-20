# Graphics Preview Overview

`WaylandGraphicsPreview` is a renderer-neutral, source-breaking preview product
for graphics-backed Wayland windows. It lets public users request software
backing, managed GPU clear-frame presentation, or renderer-owned external-buffer
presentation, then inspect typed runtime-path facts.

## What It Is

The preview API wraps a public ``WaylandGraphicsWindowBacking`` around a
`Window`. Applications lease a frame, inspect the frame contract, submit clear
frames, software drawing work, or one-plane external buffers, and receive typed
runtime-path facts.

External-buffer submission is intentionally narrow. WCK imports and commits a
move-only descriptor, tracks compositor release, and returns a
``WaylandGraphicsExternalBufferSubmissionReceipt``. The renderer keeps its own GPU
allocation alive until the receipt reaches a terminal release result.

## Choosing Backing

Use ``WaylandGraphicsConfiguration`` to request:

- `WaylandGraphicsBackingKind.software` for software-only backing.
- `WaylandGraphicsBackingKind.managedGPU` for managed GPU clear-frame attempts
  and external-buffer presentation.

Use ``WaylandGraphicsFallbackPolicy`` to choose whether GPU failures may fall
back to software or must throw a typed ``WaylandGraphicsError``.

## Current External Buffer Scope

- One-plane XRGB8888 or ARGB8888 images.
- Public move-only descriptors that consume `OwnedFileDescriptor`.
- Implicit synchronization only for external-buffer submission.
- Release-gated reuse through ``WaylandGraphicsExternalBufferSubmissionReceipt``.

## Example

See `GPUPreviewSmokeClient` in `Examples/GPUPreviewSmokeClient`,
`GraphicsPreviewManagedGPUClear` in `Examples/GraphicsPreviewManagedGPUClear`,
and `GraphicsPreviewExternalBufferSmoke` in
`Examples/GraphicsPreviewExternalBufferSmoke`.
