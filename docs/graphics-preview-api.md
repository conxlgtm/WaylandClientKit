# Graphics Preview API

`WaylandGraphicsPreview` is a preview library product for renderer-facing
experiments. It is intentionally smaller than a renderer API: it reports
capabilities, projected runtime path facts, and fallback decisions, but it does
not expose raw Wayland, EGL, GBM, DRM, or syncobj handles.

The stable-ish client surface remains `WaylandClient`. Importing
`WaylandGraphicsPreview` is an explicit opt-in to preview graphics types that
may change before a foundation candidate.

## Current Decision

`WaylandGraphicsPreview` now has two managed backing paths: software backing and
package-internal managed GPU backing. `.managedGPU` attempts real surface
dmabuf feedback, format/modifier selection, render-node selection, GBM device
creation, EGL/GLES clear rendering, dmabuf import, and owner-thread surface
presentation. It still does not expose raw GPU handles and it is not promoted to
stable API.

The compositor matrix still needs broader graphics-preview rows before this
preview path can support foundation-candidate claims. Public GBM, EGL, DRM,
dmabuf, or syncobj handles remain out of scope.

`GPUPreviewSmokeClient` is the live evidence tool for this product. Its output
uses one line per runtime-path fact so a compositor run can be pasted into
`docs/compositor-matrix.md` without inferring whether a protocol was advertised,
configured, active, failed, or selected as software fallback.
`GraphicsPreviewManagedGPUClear` is the small managed submission example: it
requests managed GPU backing with software fallback allowed, submits one clear
frame, prints the actual runtime path, fallback or failure reason, and
release/reuse status, and closes.

## Current Scope

The preview product exposes:

- `WaylandGraphicsSurfaceCapabilities`
- `WaylandGraphicsRuntimePath`
- `WaylandGraphicsFallbackPolicy`
- `WaylandGraphicsBackingDecision`
- `WaylandGraphicsConfiguration`
- `WaylandGraphicsBackingKind`
- `WaylandGraphicsWindowBacking`
- `WaylandGraphicsFrameLease`
- `WaylandGraphicsSubmittedFrame`
- `WaylandGraphicsClearFrame`
- `WaylandGraphicsXRGBColor`
- `WaylandGraphicsFrameMetadata`
- `WaylandGraphicsDamageRegion`
- `WaylandGraphicsFrameResult`
- `WaylandGraphicsPresentationFeedbackPolicy`
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
API can create a window backing, lease a frame, cancel a lease, submit a
deterministic clear frame, and submit arbitrary software drawing through a
borrowed `SoftwareFrame`.

For `.managedGPU`, clear-frame submission attempts the package-internal GPU
path. Missing dmabuf, missing per-surface feedback, missing compatible
format/modifier, render-node lookup failure, GBM allocation failure, EGL
failure, dmabuf import rejection, metadata failure, and presentation failure are
reported through typed public fallback or unavailable reasons. The public result
only reports `.active` GPU backing after a GPU-rendered buffer has been imported
and committed; display-level dmabuf advertisement alone remains `.advertised`.

## Managed Submission Boundary

`WaylandGraphicsConfiguration` describes fallback, synchronization, pacing,
metadata, presentation-feedback, and backing preferences. Defaults are
conservative: managed GPU backing is requested, software fallback is allowed,
implicit synchronization is used, pacing is not requested, metadata is opt-in,
and presentation feedback is not requested. `backingPreference: .software`
selects software backing directly. `backingPreference: .managedGPU` attempts
the managed GPU path and then follows the fallback policy when that path is not
available. `.software` and `.forceSoftware` never attempt GPU setup.
`requireExplicit` fails with a typed unavailable reason until managed
explicit-sync GPU submission exists, and pacing policies are rejected with
`WaylandGraphicsError.unsupportedPacing` until managed pacing is implemented.
`requestWhenAvailable` presentation feedback requests feedback only when the
protocol is advertised; `require` fails when it is unavailable.

`WaylandGraphicsWindowBacking` owns a managed `Window` and exposes the current
runtime path. `nextFrame()` returns a single-use `WaylandGraphicsFrameLease`.
Callers submit a `WaylandGraphicsSubmittedFrame.clearColor`, submit arbitrary
software drawing with `submitSoftware`, or cancel the lease. `clearColor` uses
the active managed GPU path when setup and submission succeed; it falls back to
the software path only when the fallback policy allows that. Submission returns
`WaylandGraphicsFrameResult`, which reports runtime path, submitted operation,
buffer size, metadata, synchronization policy, pacing policy, backing status,
and whether presentation feedback was requested. The result does not imply
presentation feedback was observed; feedback still arrives through
`WindowPresentationEvents`. The lease does not expose Wayland proxies, fds, SHM
pools, GBM buffers, EGL surfaces, DRM nodes, or syncobj handles.

`WaylandGraphicsFrameMetadata` currently exposes only content type and
presentation hint values plus `WaylandGraphicsDamageRegion`. Content type and
presentation hint map to the package-internal surface commit metadata when the
compositor advertises the relevant protocols. Public color-management image
descriptions remain internal. Full-frame damage is the default. Partial damage
is converted to `SurfaceDamageRegion` for managed software submissions and then
mapped from logical surface coordinates to the active buffer damage coordinates.
Partial overhang is clipped to the surface bounds; damage with no intersection
is rejected as `WaylandGraphicsError.invalidDamageRegion`. Unsupported frame
metadata and invalid damage are validated before the lease is consumed, so
callers can cancel or retry the active lease deterministically.

## External Compile Contract

`IntegrationTests/GraphicsPreviewClient` imports both `WaylandClient` and
`WaylandGraphicsPreview`. It verifies that external packages can compile the
preview value model, `WaylandDisplay` extension methods, managed backing,
frame lease, cancel/submit surface, software submission closure, frame result,
and clear-frame types without requiring a GPU-capable compositor.

## Breakage Policy

The preview product is allowed to make source-breaking changes while the GPU
backing foundation is still under development. Ordinary `WaylandClient` APIs do
not become renderer APIs by implication, and metadata/color protocol internals
remain package-internal until their public shape has live compositor evidence.
