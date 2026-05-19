# Graphics Preview API

`WaylandGraphicsPreview` is a preview library product for renderer-facing
experiments. It is intentionally smaller than a renderer API: it reports
capabilities, projected runtime path facts, and fallback decisions, but it does
not expose raw Wayland, EGL, GBM, DRM, or syncobj handles.

The stable-ish client surface remains `WaylandClient`. Importing
`WaylandGraphicsPreview` is an explicit opt-in to preview graphics types that
may change before a foundation candidate.

## Current Scope

The preview product exposes:

- `WaylandGraphicsSurfaceCapabilities`
- `WaylandGraphicsRuntimePath`
- `WaylandGraphicsFallbackPolicy`
- `WaylandGraphicsBackingDecision`
- small status and reason enums used by those values
- `WaylandDisplay.graphicsSurfaceCapabilities()`
- `WaylandDisplay.graphicsRuntimePath(policy:)`
- `WaylandDisplay.graphicsBackingDecision(policy:)`

These APIs are renderer-neutral. They do not define a swapchain, drawable,
scene graph, shader model, or color-management API.

## Fallback Policy

`WaylandGraphicsFallbackPolicy` separates three decisions:

- `preferGPUFallbackToSoftware`: use GPU facts when usable, otherwise report a
  software fallback reason.
- `requireGPU`: report GPU unavailability instead of hiding it behind SHM.
- `forceSoftware`: choose software even when GPU-related protocols are present.

The current public preview projection is capability-only. It can report that a
protocol is advertised and can explain why a software fallback would be chosen,
but it does not allocate GBM buffers or create EGL resources from public API.
Those effectful paths remain package-internal while the backing state machine
and compositor matrix mature.

## External Compile Contract

`IntegrationTests/GraphicsPreviewClient` imports both `WaylandClient` and
`WaylandGraphicsPreview`. It verifies that external packages can compile the
preview value model and `WaylandDisplay` extension methods without requiring a
GPU-capable compositor.

## Breakage Policy

The preview product is allowed to make source-breaking changes while the GPU
backing foundation is still under development. Ordinary `WaylandClient` APIs do
not become renderer APIs by implication, and metadata/color protocol internals
remain package-internal until their public shape has live compositor evidence.
