# Graphics Preview Overview

`WaylandGraphicsPreview` is a renderer-neutral, source-breaking preview product
for graphics-backed Wayland windows. It lets public users request software
backing, managed GPU clear-frame presentation, or renderer-owned external-buffer
presentation, then inspect typed runtime-path facts.

## What It Is

The preview API wraps a public ``WaylandGraphicsWindowBacking`` around a
`Window`. Applications lease a frame, inspect the frame contract, submit clear
frames, software drawing work, or registered renderer-owned external buffers,
and receive typed runtime-path facts.

External-buffer submission is intentionally narrow. Public move-only descriptors
consume owned dma-buf and syncobj file descriptors, WCK commits reserved buffers,
tracks compositor release, and returns a public receipt for each submitted use.
The renderer keeps each GPU allocation alive until the corresponding receipt
reaches a terminal release result.

## Choosing Backing

Use ``WaylandGraphicsConfiguration`` to request:

- `WaylandGraphicsPresentationPolicy.software` for software-only backing.
- `WaylandGraphicsPresentationPolicy.managedGPU(fallback:)` for managed GPU
  clear-frame attempts.
- `WaylandGraphicsPresentationPolicy.externalGPU(fallback:)` for renderer-owned
  external buffers.

The associated ``WaylandGraphicsFallbackDisposition`` chooses whether a GPU
failure may fall back to software or must throw a typed
``WaylandGraphicsError``. Because presentation and fallback are one policy,
software cannot carry a GPU requirement and a GPU path cannot be forced to
software before it is attempted.

## Current External Buffer Scope

- One-to-four-plane XRGB8888 or ARGB8888 images.
- Public move-only descriptors that consume `OwnedFileDescriptor` ownership.
- Persistent registration and release-gated reservation.
- Implicit synchronization and DRM syncobj explicit synchronization.
- Release-gated reuse through public submission receipts.

## Example

See `GPUPreviewSmokeClient` in `Examples/GPUPreviewSmokeClient`,
`GraphicsPreviewManagedGPUClear` in `Examples/GraphicsPreviewManagedGPUClear`,
and `GraphicsPreviewExternalBufferSmoke` in
`Examples/GraphicsPreviewExternalBufferSmoke`.
