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
- `WaylandGraphicsConfiguration`
- `WaylandGraphicsWindowBacking`
- `WaylandGraphicsFrameLease`
- `WaylandGraphicsSubmittedFrame`
- `WaylandGraphicsClearFrame`
- `WaylandGraphicsXRGBColor`
- `WaylandGraphicsFrameMetadata`
- `WaylandGraphicsError`
- small status and reason enums used by those values
- `WaylandDisplay.graphicsSurfaceCapabilities()`
- `WaylandDisplay.graphicsRuntimePath(policy:)`
- `WaylandDisplay.graphicsBackingDecision(policy:)`
- `WaylandDisplay.createGraphicsWindowBacking(windowConfiguration:graphicsConfiguration:)`

These APIs are renderer-neutral. They do not define a swapchain, drawable,
scene graph, shader model, or color-management API.

## Fallback Policy

`WaylandGraphicsFallbackPolicy` separates three decisions:

- `preferGPUFallbackToSoftware`: use GPU facts when usable, otherwise report a
  software fallback reason.
- `requireGPU`: report GPU unavailability instead of hiding it behind SHM.
- `forceSoftware`: choose software even when GPU-related protocols are present.

The public preview projection can report that a protocol is advertised and can
explain why a software fallback would be chosen. The managed preview submission
API can create a window backing, lease a frame, cancel a lease, and submit a
deterministic clear frame. The first managed submission path remains software
backed and reports GPU fallback reasons explicitly; GBM/EGL allocation and
compositor dmabuf import remain package-internal while the backing state
machine and compositor matrix mature.

## Managed Submission Boundary

`WaylandGraphicsConfiguration` describes fallback, synchronization, pacing, and
metadata preferences. Defaults are conservative: software fallback is allowed,
implicit synchronization is used, pacing is not requested, and public metadata
requests are disabled.

`WaylandGraphicsWindowBacking` owns a managed `Window` and exposes the current
runtime path. `nextFrame()` returns a single-use `WaylandGraphicsFrameLease`.
Callers either submit a `WaylandGraphicsSubmittedFrame.clearColor` frame or
cancel the lease. The lease does not expose Wayland proxies, fds, GBM buffers,
EGL surfaces, DRM nodes, or syncobj handles.

`WaylandGraphicsFrameMetadata` currently exposes only content type and
presentation hint values. The managed clear-frame implementation rejects
non-default metadata with `WaylandGraphicsError.unsupportedMetadata`; public
color-management image descriptions remain internal.

## External Compile Contract

`IntegrationTests/GraphicsPreviewClient` imports both `WaylandClient` and
`WaylandGraphicsPreview`. It verifies that external packages can compile the
preview value model, `WaylandDisplay` extension methods, managed backing,
frame lease, cancel/submit surface, and clear-frame types without requiring a
GPU-capable compositor.

## Breakage Policy

The preview product is allowed to make source-breaking changes while the GPU
backing foundation is still under development. Ordinary `WaylandClient` APIs do
not become renderer APIs by implication, and metadata/color protocol internals
remain package-internal until their public shape has live compositor evidence.
