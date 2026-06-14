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

Current live evidence proves active managed GPU clear-frame submission,
explicit synchronization, FIFO pacing, content-type metadata, and
presentation-hint/tearing metadata on KDE/KWin. Commit timing is implemented as
a runtime-path request with typed fallback/failure reporting, but it is not yet
live-proven active in the compositor matrix because the current KDE/KWin
session does not advertise it.
External buffer submission and public frame scheduling are preview APIs. Active
runtime status means the requested behavior was applied to a submitted frame;
advertised status means only that the compositor exposed the protocol.

`GPUPreviewSmokeClient` is the live evidence tool for this product. Its output
uses one line per runtime-path fact so a compositor run can be pasted into
`docs/compositor-matrix.md` without inferring whether a protocol was advertised,
configured, active, failed, or selected as software fallback.
`GraphicsPreviewManagedGPUClear` is the small managed submission example: it
requests managed GPU backing with software fallback allowed, keeps an
interactive clear-frame window open by default, logs each show/redraw frame
size, prints the actual runtime path, fallback or failure reason, release/reuse
status, and whether a resize was observed, then closes when the compositor
requests close. The manual resize path uses an in-content edge/corner handle,
so drag from inside the clear window edge instead of relying on compositor
decorations. Use `--auto-close --print-summary` for bounded evidence runs.
Both GPU smoke tools accept `--sync implicit-only|prefer-explicit|require-explicit`
and `--pacing none|fifo|commit-timing`. `GraphicsPreviewManagedGPUClear` also
accepts `--metadata none|prefer`, `--content-type none|photo|video|game`, and
`--presentation-hint vsync|async`. `GraphicsPreviewExternalBufferSmoke`,
`GraphicsPreviewColorMetadataSmoke`, `ColorManagementSmoke`, and
`OutputTopologySmoke` provide bounded probes for external buffers, color
metadata, color capability facts, and output topology.
`GraphicsPreviewExternalBufferSmoke -- --internal-test-buffer` intentionally
uses a pipe descriptor rather than a real dmabuf, so it is a negative
import-failure cleanup probe. Active external-buffer evidence still requires a
renderer-produced dmabuf run that imports, commits, releases, and cleans up.

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
- `WaylandGraphicsFrameSchedule`
- `WaylandGraphicsFramePacingRequest`
- `WaylandGraphicsCommitTimingRequest`
- `WaylandGraphicsPresentationTarget`
- `WaylandGraphicsAlphaModifier`
- `WaylandGraphicsColorRepresentation`
- `WaylandGraphicsColorAlphaMode`
- `WaylandGraphicsColorDescriptionID`
- `WaylandGraphicsColorDescription`
- `WaylandGraphicsDRMFormat`
- `WaylandGraphicsDRMFormatModifier`
- `WaylandGraphicsExternalBufferPlane`
- `WaylandGraphicsExternalBufferPlanes`
- `WaylandGraphicsExternalBufferDescriptor`
- `WaylandGraphicsExternalSynchronization`
- `WaylandGraphicsExternalAcquireSync`
- `WaylandGraphicsError`
- small status and reason enums used by those values
- `WaylandDisplay.graphicsSurfaceCapabilities()`
- `WaylandDisplay.graphicsRuntimePath(policy:)`
- `WaylandDisplay.graphicsBackingDecision(policy:)`
- `WaylandDisplay.createGraphicsWindowBacking(windowConfiguration:graphicsConfiguration:)`

These APIs are renderer-neutral. They do not define a swapchain, drawable,
scene graph, shader model, tone-mapping path, or renderer color pipeline.

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
path. External-buffer submission imports a caller-rendered dmabuf descriptor and
commits it through the same owner-thread surface path. The renderer owns
rendering and buffer production; WaylandClientKit owns Wayland buffer import,
commit, release tracking, and late-release cleanup. Missing dmabuf, missing
per-surface feedback, missing compatible format/modifier, render-node lookup
failure, GBM allocation failure, EGL failure, dmabuf import rejection, external
buffer import failure, metadata failure, and presentation failure are reported
through typed public fallback or unavailable reasons. The public result only
reports `.active` GPU backing after a GPU-rendered or imported external buffer
has been committed; display-level dmabuf advertisement alone remains
`.advertised`.
`WaylandGraphicsRuntimePath` separates dmabuf advertisement, per-surface
feedback, render-node selection, GBM, EGL, dmabuf import, buffer lifecycle,
synchronization, pacing, metadata, and presentation-feedback status so callers
can tell which managed GPU stage configured, became active, failed, or fell back.

## Managed Submission Boundary

`WaylandGraphicsConfiguration` describes fallback, synchronization, pacing,
metadata, presentation-feedback, and backing preferences. Defaults are
conservative: managed GPU backing is requested, software fallback is allowed,
implicit synchronization is used, pacing is not requested, metadata is opt-in,
and presentation feedback is not requested. `backingPreference: .software`
selects software backing directly. `backingPreference: .managedGPU` attempts
the managed GPU path and then follows the fallback policy when that path is not
available. `.software` and `.forceSoftware` never attempt GPU setup.
`implicitOnly` never requests explicit synchronization. `preferExplicit`
attempts linux-drm-syncobj when the compositor advertises it and the managed
GPU path can import a sync timeline; otherwise it falls back to implicit sync
with an explicit runtime fallback reason before explicit synchronization has
been installed on the surface. After explicit synchronization is configured or
active on the surface, implicit software fallback is rejected with a typed
unavailable reason. `requireExplicit` never silently falls back: it succeeds
only when explicit sync is configured for the submitted managed GPU frame.
Software backing preferences, forced software fallback, and managed GPU
setup/submission/release failures fail with typed unavailable reasons instead
of committing implicit software frames.
`WaylandGraphicsFrameSchedule` lets callers override synchronization, pacing,
and presentation-feedback policy per submitted frame. `WaylandGraphicsFrameResult`
records the effective schedule and post-submission runtime path, so callers can
compare requested synchronization, FIFO, commit timing, and feedback policy with
the compositor-mediated result. Public scheduling does not expose syncobj
timelines, raw fences, or protocol objects. Frameworks own animation policy;
WaylandClientKit exposes timing facts and commit requests.
`preferFIFO` and `preferCommitTiming` apply the matching submit constraint to
managed GPU commits, direct software commits, and allowed software fallback
commits when the protocol is available. Missing FIFO or commit-timing support is
reported as a pacing fallback reason. Commit-timing timestamp rejection is
reported as a typed failure. Public commit timing currently accepts
`WaylandGraphicsPresentationTarget.default`, which uses WaylandClientKit's
preview default target for the next frame. Current live compositor evidence
proves FIFO active and commit-timing fallback, but not commit-timing active.
FIFO pacing primes the surface with `set_barrier` on the first successful
FIFO-paced commit, then waits on the previous barrier and sets the next barrier
on later FIFO-paced commits.
`requestWhenAvailable` presentation feedback requests feedback only when the
protocol is advertised; `require` fails when it is unavailable.

`WaylandGraphicsWindowBacking` owns a managed `Window` and exposes the current
runtime path. `nextFrame()` returns a single-use `WaylandGraphicsFrameLease`.
Callers submit a `WaylandGraphicsSubmittedFrame.clearColor`, submit an external
dmabuf descriptor with `submitExternalBuffer`, submit arbitrary software drawing
with `submitSoftware`, or cancel the lease. `clearColor` uses the active managed
GPU path when setup and submission succeed; it falls back to the software path
only when the fallback policy and surface synchronization state allow an
implicit software commit. External-buffer submission never claims software
fallback as an external-buffer success. `requireGPU` fails if the external
import/commit path cannot be used. Submission returns
`WaylandGraphicsFrameResult`, which reports runtime path, submitted operation,
buffer size, metadata, schedule, synchronization policy, pacing policy, backing
status, and whether presentation feedback was requested. The result does not
imply presentation feedback was observed; feedback still arrives through
`WindowPresentationEvents`. The lease does not expose Wayland proxies, SHM
pools, GBM buffers, EGL surfaces, DRM nodes, or syncobj handles. External
buffer descriptors expose only owned Linux plane descriptors and format/modifier
facts needed to integrate a renderer-owned dmabuf; descriptor validation covers
size, format, modifier, plane count, consecutive plane indices, stride, offset,
and ownership transfer.

`WaylandGraphicsFrameMetadata` exposes content type, presentation hint, alpha
modifier, color representation, color-description reference, and
`WaylandGraphicsDamageRegion`. With `metadataPolicy: .preferAvailable`,
supported metadata maps to package-internal surface commit metadata when the
compositor advertises the relevant protocols. Missing preferred metadata
protocols are omitted from the commit and reported in the runtime path with
typed fallback reasons such as `contentTypeUnavailable`,
`presentationHintUnavailable`, `alphaModifierUnavailable`,
`colorRepresentationUnavailable`, or `colorManagementUnavailable`;
`metadataPolicy: .none` rejects non-default metadata. Image descriptions remain
opaque identifiers. WaylandClientKit applies protocol metadata; it does not own
renderer color conversion, tone mapping, asset color policy, or scene/rendering
policy.

Full-frame damage is the default. Partial damage is converted to
`SurfaceDamageRegion` for managed software submissions and then mapped from
logical surface coordinates to the active buffer damage coordinates. Partial
overhang is clipped to the surface bounds; damage with no intersection is
rejected as `WaylandGraphicsError.invalidDamageRegion`. Unsupported frame
metadata and invalid damage are validated before the lease is consumed, so
callers can cancel or retry the active lease deterministically.

## External Compile Contract

`IntegrationTests/GraphicsPreviewClient` imports both `WaylandClient` and
`WaylandGraphicsPreview`. It verifies that external packages can compile the
preview value model, `WaylandDisplay` extension methods, managed backing,
frame lease, cancel/submit surface, software submission closure, external
buffer descriptors, schedule values, frame result, and clear-frame types
without requiring a GPU-capable compositor.

## Breakage Policy

The preview product is allowed to make source-breaking changes while the GPU
backing foundation is still under development. Ordinary `WaylandClient` APIs do
not become renderer APIs by implication, and metadata/color protocol internals
remain package-internal until their public shape has live compositor evidence.
