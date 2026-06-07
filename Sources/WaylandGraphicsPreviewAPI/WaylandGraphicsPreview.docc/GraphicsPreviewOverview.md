# Graphics Preview Overview

`WaylandGraphicsPreview` is a renderer-neutral preview product for managed
graphics-backed windows. It lets public users request software backing or
managed GPU backing without importing internal GPU targets or receiving raw
protocol handles.

## What It Is

The preview API wraps a public ``WaylandGraphicsWindowBacking`` around a
`WaylandClient.Window`. Applications lease a frame, submit a clear frame or
software drawing work, and receive a ``WaylandGraphicsFrameResult`` with typed
runtime-path facts.

## What It Is Not

It is not a renderer, scene graph, swapchain API, retained UI framework, widget
toolkit, layout engine, styling system, or public GPU handle layer. Frameworks
remain responsible for renderer choice and user-interface policy.

## Choosing Backing

Use ``WaylandGraphicsConfiguration`` to request:

- `WaylandGraphicsBackingKind.software` for software-only backing.
- `WaylandGraphicsBackingKind.managedGPU` for an internal managed GPU attempt.

Use ``WaylandGraphicsFallbackPolicy`` to choose whether managed GPU failures may
fall back to software or must throw a typed ``WaylandGraphicsError``.

## Example

See `GPUPreviewSmokeClient` in `Examples/GPUPreviewSmokeClient` and
`GraphicsPreviewManagedGPUClear` in `Examples/GraphicsPreviewManagedGPUClear`.
