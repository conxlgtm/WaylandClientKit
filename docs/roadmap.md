# Roadmap

Status: active planning document  
Date: 2026-05-12  
Scope: SwiftWayland as a Swift-native Linux Wayland platform foundation

This roadmap defines the path from the current experimental substrate to a
foundation that a higher Swift GUI framework can rely on for serious Linux
desktop applications. It intentionally does not estimate dates.

SwiftWayland should remain the platform substrate. It should not become the
SwiftUI-like layer, a retained widget toolkit, a renderer, a scene graph, or an
application framework.

## Completion Target

The completion target is:

- a higher GUI framework can create and manage Wayland desktop windows without
  touching raw Wayland objects
- a renderer can submit GPU-backed frames without owning Wayland protocol
  lifetime rules
- surface transaction behavior is explicit across SHM, GPU buffers, cursors,
  drag icons, popups, scale changes, and presentation feedback
- input, text input, clipboard, drag-and-drop, cursor, output, timing, color
  metadata, and diagnostics are available as typed Swift APIs
- display-level, seat-level, surface-level, and runtime-path capabilities are
  modeled separately
- optional compositor support is reported honestly through capabilities and
  typed errors
- SHM software rendering remains available as a fallback and test baseline
- normal compositor differences are covered by live tests and documented
  behavior
- public API boundaries are clear enough for downstream packages to depend on
  them
- external framework-consumer checks prove a future GUI package can import only
  public products and still exercise host lifecycle, events, windows, popups,
  and preview graphics software submission

This target is not met until a GPU buffer path exists. A software-only SHM
client is useful, but it is not a complete foundation for a modern GUI stack.

## Foundation Checkpoint 1

A development checkpoint is useful before claiming the full foundation target.
Checkpoint 1 means the current public and package-internal substrate is ready
for the next protocol family without changing the compatibility promise.

The checkpoint bar is:

- public API audit, baseline, DocC link, protocol manifest, and target-import
  gates pass
- DocC concept pages exist for display lifecycle, windows, input, text input,
  data transfer, cursor behavior, capabilities, events, presentation, and
  diagnostics
- text-input request lifecycle and transaction behavior are represented by
  tested state values
- cursor-shape fallback, cursor role surfaces, cursor scale policy, cursor
  animation state, and drag icon lifetimes have focused tests
- event stream capacity and overflow behavior is local to the documented stream
  family
- `SurfaceRuntime` role transitions are tested for all current roles
- the compositor matrix has collected data for headless Weston and at least one
  desktop compositor before a release candidate
- GPU preview keeps raw GBM/EGL/dmabuf handles package-internal while the
  public `WaylandGraphicsPreview` product reports capability skips, runtime
  path failures, and managed clear-frame software fallback without becoming a
  renderer API
- the strict memory-safety audit covers current fd, proxy, callback, surface,
  GBM, EGL, dmabuf, text-input, cursor, and drag-icon ownership rules

This checkpoint is not a foundation release candidate. Public raw GPU handles,
renderer-owned swapchains, color-management image descriptions, and
output-management work remain later milestones.

## Non-Goals

These belong above SwiftWayland:

- declarative view trees
- layout systems
- widgets
- gesture recognizers
- text editor widgets
- styling and themes
- app commands and document lifecycle
- accessibility semantic trees
- renderer scene graphs
- render graphs, shaders, and drawing commands
- tone mapping, color conversion, and asset color policy

SwiftWayland may expose facts these systems need. It should not own their
policy.

SwiftWayland should preserve low-level platform facts that later accessibility
or application-framework layers may need, such as toplevel identity, focus
state, text-input state, output and scale facts, activation/session facts, and
system-bell capability. It should not own accessibility semantics.

## Current Baseline

The current baseline already has meaningful substrate pieces:

- SwiftPM target structure with one public `WaylandClient` product
- generated Wayland protocol artifacts and project-owned C shims
- display connection, registry discovery, and version-negotiated binding
- owner-thread event loop integration
- xdg-shell toplevel windows and popups
- server-side decoration negotiation
- scale-aware SHM software rendering
- viewporter and fractional-scale integration for SHM buffers
- frame callback pacing
- public output snapshots and surface output membership
- xkbcommon-backed keyboard interpretation
- pointer, keyboard, and touch event capture
- static cursor surfaces through `wayland-cursor`
- compositor cursor-shape requests for mapped pointer cursors
- regular clipboard, primary selection, receive-side drag-and-drop, and
  source-side drag-and-drop
- managed XRGB8888 drag icon surfaces for source-side drags
- seat-scoped text-input sessions and text-input event streams
- presentation-time support
- shared surface transaction state for SHM and preview GPU commits
- linux-dmabuf raw objects, feedback parsing, and buffer params lifecycle
- GBM/DRM allocation, modifier selection, dmabuf export, and buffer-pool state
- package-internal EGL/GLES render target probe through `WaylandGraphicsCore`
- package-internal GPU window presentation bridge through `WaylandGPUPreview`
- preview graphics product `WaylandGraphicsPreview` for renderer-neutral
  capability, runtime-path, and fallback facts
- managed software submission in `WaylandGraphicsPreview` for framework-facing
  software rendering experiments without raw platform handles
- framework-host contract documentation and external consumer packages that
  exercise public host-loop and tiny UI prototype shapes
- package-internal submit-constraint model for linux-drm-syncobj, FIFO, and
  commit-timing capability facts
- package-internal surface commit metadata model for content type, alpha,
  tearing-control hints, color representation, and color-management references
- live/headless Wayland smoke paths
- strict Swift memory-safety diagnostics as errors

Known foundation gaps:

- extending the shared surface transaction model to cursor, drag icon, and future
  subsurface use
- live compositor coverage for the package-internal GPU window presentation path
- broader live compositor coverage for explicit sync, FIFO, commit timing, and
  metadata protocols beyond local unit and smoke reporting
- public cursor animation and output-scale cursor policy APIs
- advanced pointer and tablet protocols
- xdg-session-management and activation/session integration where needed by app
  launch and restoration workflows
- compositor matrix coverage beyond headless Weston
- public DocC reference documentation
- compatibility and release policy for stable client APIs and preview graphics
  APIs

## Roadmap Principles

- Keep public API protocol-truthful. Do not hide serials, capability absence,
  focus rules, fd lifetime, or commit ordering when a backend must know them.
- Treat surface state as the central abstraction below windows, popups, cursor
  surfaces, drag icons, and future graphics backings.
- Keep raw Wayland, C shims, file descriptors, EGL/GBM handles, DRM handles, and
  protocol listener state out of ordinary downstream API.
- Add GPU as a first-class foundation path, not as a demo-only experiment.
- Keep SHM as a reliable fallback path and testing baseline.
- Prefer capability-gated behavior over pretending unsupported compositor
  features exist.
- Model capabilities at the scope where the protocol fact is true. A global
  registry advertisement is not enough for surface-specific dmabuf feedback,
  fractional scale, output membership, presentation, or color facts.
- Avoid naming generic renderer abstractions until at least two backing paths
  prove the shape.
- Treat live compositor behavior as product evidence. Weston-only behavior is
  not enough.
- Treat resource semantics as part of each protocol milestone, not as a later
  audit.

## External References

These sources shape the roadmap:

- Wayland protocols have stable, staging, experimental, deprecated, and legacy
  unstable phases with different compatibility expectations:
  <https://chromium.googlesource.com/external/anongit.freedesktop.org/git/wayland/wayland-protocols/+/refs/heads/main>
- `wp_presentation` provides presentation timestamps, refresh estimates,
  sequence values, synchronized output, and presented/discarded feedback:
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/stable/presentation-time/presentation-time.xml>
- Wayland protocols 1.38 added staging FIFO and commit-timing protocols and
  updated presentation timing text around variable refresh behavior:
  <https://lists.freedesktop.org/archives/wayland-devel/2024-October/043851.html>
- `wp_fractional_scale_v1` requires viewport-based scaled content, keeps
  `wl_surface` buffer scale at 1, and reports preferred scale as a fraction with
  denominator 120:
  <https://wayland.app/protocols/fractional-scale-v1>
- `zwp_linux_dmabuf_v1` creates dmabuf-backed `wl_buffer` objects and provides
  default/per-surface feedback for preferred devices, formats, modifiers, and
  tranches:
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml>
- Linux dma-buf is the kernel buffer sharing and synchronization framework:
  <https://docs.kernel.org/driver-api/dma-buf.html>
- `linux-drm-syncobj` gives explicit acquire/release synchronization points for
  Wayland surface commits:
  <https://wayland.app/protocols/linux-drm-syncobj-v1>
- EGL is the native platform interface for graphics context management and
  rendering surfaces:
  <https://www.khronos.org/egl>
- Mesa EGL is the practical Linux implementation path used by common Linux
  graphics stacks:
  <https://docs.mesa3d.org/egl.html>
- Mesa GBM exposes buffer object and surface APIs, including modifier-aware
  allocation functions:
  <https://cgit.freedesktop.org/mesa/mesa/tree/src/gbm/main/gbm.h>
- `EGL_EXT_image_dma_buf_import_modifiers` defines modifier-aware dma-buf image
  import behavior and query functions:
  <https://registry.khronos.org/EGL/extensions/EXT/EGL_EXT_image_dma_buf_import_modifiers.txt>
- Wayland protocols 1.47 added color-management updates, including a new image
  description reference object and transfer-function changes:
  <https://www.mail-archive.com/wayland-devel%40lists.freedesktop.org/msg44025.html>
- The color-management protocol lets clients observe output/preferred image
  descriptions and attach surface content color descriptions:
  <https://wayland.app/protocols/color-management-v1>
- `text-input-v3` defines the client-side protocol for compositor/input-method
  text entry:
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/unstable/text-input/text-input-unstable-v3.xml>
- Wayland protocols 1.48 added XDG Session Management and text-input changes
  such as input panel requests, preedit hints, language hints, and on-screen
  input hints:
  <https://www.mail-archive.com/wayland-devel%40lists.freedesktop.org/msg44067.html>
- `cursor-shape-v1` is the compositor-managed cursor shape protocol:
  <https://wayland.app/protocols/cursor-shape-v1>
- relative pointer, pointer constraints, tablet, and pointer warp protocols
  cover advanced input devices and locked/relative pointer use cases:
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/unstable/relative-pointer/relative-pointer-unstable-v1.xml>
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml>
  <https://cgit.freedesktop.org/wayland/wayland-protocols/tree/unstable/tablet/tablet-unstable-v2.xml>
  <https://wayland.app/protocols/pointer-warp-v1>
- Swift 6.2 introduced opt-in strict memory safety diagnostics:
  <https://www.swift.org/blog/swift-6.2-released/>
- Swift 6.3 added more flexible C interoperability and SwiftPM Swift Build
  integration previews:
  <https://www.swift.org/blog/swift-6.3-released/>

## Protocol Phase And Support Tiers

SwiftWayland should track upstream protocol phase separately from product
support tier. These are related facts, not the same fact.

| Protocol | Upstream phase | SwiftWayland tier | API exposure | Test strategy | Breakage policy |
| --- | --- | --- | --- | --- | --- |
| `wl_compositor`, `wl_surface`, `wl_shm`, `wl_seat` | core | required | public through `WaylandClient` concepts | always tested | no intentional break after foundation candidate |
| `xdg-shell` | stable | required | public windows/popups | always tested | no intentional break after foundation candidate |
| `wp_viewporter` | stable | required for scaled buffers | public capability plus internal surface state | unit and live where advertised | stable protocol, product API review required |
| `wp_presentation` | stable | optional foundation | public typed capability and events | skip/fail by advertisement | stable protocol, product API review required |
| `zwp_linux_dmabuf_v1` | legacy unstable but widely deployed | optional foundation | capability and managed buffer path; raw internal | fixture plus compositor matrix | raw internals may change; public capability semantics reviewed |
| `wp_linux_drm_syncobj_v1` | staging | optional/preview foundation | capability-gated; public facts only after proven | compositor path where advertised | allow source/API change while preview |
| `wp_fractional_scale_v1` | staging | optional but important | public capability and surface scale facts | unit and compositor matrix | allow version-gated additions |
| `wp_content_type_v1`, `wp_alpha_modifier_v1`, `wp_tearing_control_v1` | staging | optional/preview metadata | internal commit metadata first; no public renderer API yet | unit and compositor matrix where available | allow source/API change while preview |
| `wp_color_manager_v1` | staging | optional/preview metadata | internal capability facts and image-description references first | unit and compositor matrix where available | allow source/API change while preview |
| `wp_color_representation_v1` | staging | optional/preview metadata | internal commit metadata first; no public color pipeline API yet | unit and compositor matrix where available | allow source/API change while preview |
| `wp_fifo_v1`, `wp_commit_timing_v1` | staging | optional/preview pacing | capability facts before public scheduling API | compositor path where advertised | allow source/API change while preview |
| `zwp_text_input_manager_v3` | legacy unstable, active minor updates | optional foundation | public typed text-input API | live IME path where feasible | version-gated additions; preserve unknown values |
| `wp_cursor_shape_manager_v1` | staging | optional foundation | public cursor capability and requests | unit plus live where advertised | allow version-gated additions |
| `xdg_activation_v1` | stable | optional desktop integration | public typed API when implemented | live where advertised | stable protocol, product API review required |
| `xx_session_manager_v1` or promoted successor | experimental/staging as upstream evolves | preview | typed optional API only behind preview policy | smoke where available | expected to change |
| `wp_pointer_warp_v1` | staging | preview/advanced input | capability-gated only | use-case gated tests | allow source/API change while preview |

Every protocol entry should be updated when vendored or generated. The manifest
should record upstream path, phase, version, checksum, and SwiftWayland tier.

## Capability Scope Model

Capabilities should be modeled at the scope where they are true:

- Display-level capabilities: registry globals, negotiated versions, and global
  managers such as compositor, xdg-shell, data-device, presentation-time,
  dmabuf, color manager, and activation.
- Seat-level capabilities: pointer, keyboard, touch, text-input, tablet,
  relative pointer, pointer constraints, and input-method-related state.
- Surface-level capabilities: fractional scale, output membership, per-surface
  dmabuf feedback, presentation feedback availability, color metadata, content
  type, alpha/modifier behavior, and surface role constraints.
- Runtime-path capabilities: SHM available, dmabuf import usable, GBM allocation
  usable, EGL context usable, explicit sync usable, and fallback path selected.

Do not expose "display supports dmabuf" as if it means a surface has a usable
GPU path. The useful decision point for a renderer is normally the surface path:
preferred device, tranche, format/modifier set, scale, output facts, color
facts, synchronization mode, and presentation availability.

## Cross-Cutting Resource Semantics

Every protocol milestone must specify resource semantics before exit:

- object ownership and destruction rules
- callback listener lifetime and cancellation behavior
- fd ownership, close behavior, and timeout behavior
- one-shot object state transitions
- stream overflow behavior
- surface destruction behavior
- display failure behavior
- typed diagnostics and severity
- live-test skip/fail rules for optional protocols

Do not land a protocol path that only models the happy path.

## Milestone 0: Product Contract

Goal:

- Define what SwiftWayland must provide before a higher GUI framework can treat
  it as a foundation.

Work:

- publish a short product contract for `WaylandClient`
- define support tiers for protocols: required, optional foundation, preview,
  and out of scope
- define compatibility policy before the first foundation release candidate
- define what API can break while the package is experimental
- document the boundary between `WaylandClient`, any future graphics target,
  and future GUI framework layers
- require public API dumps and external package compile tests for every public
  API change
- define when preview APIs may be source-breaking

Exit criteria:

- `docs/public-api-audit.md` and this roadmap agree
- public API review has a repeatable command
- public types do not expose raw Wayland, raw C, EGL, GBM, DRM, or sync handles
  unless a separate low-level product is deliberately created
- protocol phase and support tier are recorded for every vendored non-core
  protocol

## Milestone 1: Presentation And Frame Pacing Primitives

Goal:

- Make compositor presentation feedback and future frame pacing controls
  available as platform primitives without turning them into a renderer.

Why:

- GPU buffer lifecycle and frame pacing need actual presentation facts, not just
  frame callbacks.

Active work packages:

- `docs-dnd-presentation-state`
- `presentation-protocol-generation`
- `presentation-raw-layer`
- `presentation-client-state`
- `presentation-public-api`
- `presentation-live-smoke`

Required behavior:

- bind `wp_presentation` when advertised
- expose presentation-time availability through `WaylandCapabilities`
- expose explicit per-window presentation feedback requests
- model presented and discarded outcomes
- preserve unknown presentation flags
- map synchronized output where possible
- keep frame callbacks separate from presentation feedback
- reserve room for FIFO and commit-timing protocols without collapsing them into
  frame callbacks or presentation feedback
- preserve VRR-related presentation timing facts where the protocol version
  provides them
- skip live tests when `wp_presentation` is absent
- fail live tests when an advertised `wp_presentation` path is broken

Resource semantics:

- presentation feedback objects are one-shot
- stale callbacks cannot publish into destroyed window state
- feedback streams finish on display/window close
- optional protocol absence is capability state, not a normal redraw error

Exit criteria:

- presentation feedback is observable from a managed toplevel window
- missing presentation-time support reports unavailable without breaking SHM
  redraw
- generated protocol verification, shim verification, unit tests, public API
  tests, and live/headless tests pass or skip by capability
- future FIFO/commit-timing support has a documented placement and does not
  require renaming presentation feedback APIs

## Milestone 2: Window Backing And Presenter Split

Goal:

- Stop treating a managed window as inherently SHM-backed.

Why:

- `TopLevelWindow` currently owns software drawing and surface commit behavior
  together. GPU support needs the same configure, scale, frame, presentation,
  and close lifecycle with a different buffer source.

Work:

- introduce an internal surface presenter boundary
- keep `SoftwareFrame` and SHM drawing as one presenter
- add a placeholder GPU presenter interface without exposing it publicly yet
- move shared commit planning into reusable internal code
- keep configure/ack, scale installation, frame callback, damage, and
  presentation feedback behavior shared
- define common buffer lifecycle states: drawing, submitted, released, retired,
  and failed
- define common resize behavior across SHM and GPU backings

Resource semantics:

- presenter shutdown must release or retire all outstanding buffers
- close while drawing, close while submitted, and close after release are
  distinct tested states
- a presenter cannot attach a buffer to a surface with an incompatible role or
  destroyed state

Exit criteria:

- SHM behavior is unchanged from public API
- window model tests cover presenter-independent state transitions
- a future GPU presenter can attach a non-SHM `wl_buffer` without forking the
  whole window lifecycle

## Milestone 3: Surface State, Scale, And Transaction Model

Goal:

- Make Wayland surface transaction semantics a first-class internal model shared
  by windows, popups, cursors, drag icons, SHM buffers, GPU buffers, and future
  surface roles.

Why:

- Fractional scale, GPU presentation, cursor scale, drag icons, damage,
  presentation feedback, and explicit sync are all surface-state problems. They
  should not be implemented as unrelated feature piles.

Work packages:

- `surface-transaction-model`
- `fractional-scale-contract`
- `viewport-scale-commit-plan`
- `surface-role-invariants`
- `damage-region-semantics`
- `surface-output-membership`
- `surface-capability-snapshots`
- `surface-resource-state-tests`

Required behavior:

- model configure/ack/commit ordering explicitly
- model surface role restrictions and one-role-for-life behavior
- keep logical surface size distinct from buffer-pixel size
- support integer scale and fractional scale in the same commit planner
- when using fractional scale, keep `wl_surface` buffer scale at 1, calculate
  buffer size from surface size times preferred scale, and use `wp_viewport`
  destination to map buffer pixels back to logical surface size
- preserve viewporter behavior for SHM and GPU backings
- define damage region coordinate space for buffer damage and logical damage
- model opaque and input regions before exposing them publicly
- model output enter/leave membership as surface state
- model per-surface capability facts: fractional scale, dmabuf feedback,
  presentation availability, output membership, color metadata, content type,
  and synchronization mode
- invalidate or recreate backing resources on size, scale, format, modifier,
  output, color, or sync-mode changes

Resource semantics:

- surface add-on objects are destroyed before or with their surface owner
- duplicate per-surface add-on object creation is prevented or reported before
  compositor protocol errors where possible
- surface destruction invalidates pending presentation feedback, dmabuf
  feedback, cursor animation, drag icon state, and sync objects

Exit criteria:

- SHM and future GPU presenters use the same scale and commit planning rules
- fractional scale tests cover rounding, viewport destination, damage, and
  buffer-size selection
- surface role tests cover windows, popups, cursor surfaces, and drag icon
  surfaces
- surface-scoped capability snapshots are available internally and ready for
  public API review where needed

## Milestone 4: Dmabuf Protocol Layer

Goal:

- Add the Wayland protocol layer needed to create dmabuf-backed `wl_buffer`
  objects.

Work packages:

- `dmabuf-protocol-generation`
- `dmabuf-raw-layer`
- `dmabuf-feedback-model`
- `dmabuf-buffer-params-lifecycle`
- `dmabuf-capability-reporting`
- `dmabuf-public-test-fixtures`

Required protocol coverage:

- `zwp_linux_dmabuf_v1`
- `zwp_linux_buffer_params_v1`
- `zwp_linux_dmabuf_feedback_v1`

Required behavior:

- bind the dmabuf global as optional capability
- request default feedback
- request per-surface feedback
- parse format tables from read-only mapped fds
- model main device, target device, tranche flags, and format/modifier pairs
- preserve unknown modifier and flag values
- expose display-level dmabuf advertisement separately from surface-level usable
  dmabuf paths
- create dmabuf `wl_buffer`s through the asynchronous `create` path first
- treat `create_immed` as a later fast path only after failure behavior is
  well-modeled
- destroy params objects exactly once
- close received fds on all failure paths
- expose typed nonfatal import failure results

Resource semantics:

- feedback table fds are mapped read-only and closed exactly once
- buffer params objects have explicit pending, created, failed, and destroyed
  states
- plane fds have explicit transfer/close behavior
- async buffer creation failure cannot leak params objects or fds

Exit criteria:

- the raw layer can create a `wl_buffer` from externally supplied dmabuf plane
  metadata
- dmabuf feedback is represented as immutable per-display and per-surface
  snapshots
- live tests skip when `zwp_linux_dmabuf_v1` is absent
- advertised dmabuf support is tested with a controlled fixture or compositor
  path

## Milestone 5: GBM Device And Buffer Allocation

Goal:

- Allocate GPU buffers that match compositor dmabuf feedback.

Work packages:

- `gbm-system-target`
- `drm-render-node-selection`
- `gbm-device-lifetime`
- `gbm-buffer-allocation`
- `gbm-plane-export`
- `gbm-modifier-selection`
- `gbm-buffer-pool`

Required behavior:

- add system/shim targets for GBM and the required DRM node helpers
- map compositor feedback devices to usable render nodes
- create a GBM device from the selected node
- select a format/modifier pair from per-surface feedback
- allocate buffer objects with modifiers where supported
- export fd, stride, offset, modifier, width, height, and format per plane
- keep fd ownership explicit and testable
- support a small initial set of formats needed for window rendering, starting
  with XRGB/ARGB-style formats used by common compositors
- fall back to SHM when dmabuf feedback or GBM allocation is unavailable

Resource semantics:

- render node fds are owned and closed predictably
- GBM device lifetime exceeds all buffer objects allocated from it
- buffer objects are not destroyed while exported Wayland buffers may still be
  in use
- modifier selection failures report the missing constraint, not a generic GPU
  failure

Exit criteria:

- a GBM buffer can be allocated from a compositor-compatible format/modifier
  choice
- exported plane metadata can feed the dmabuf buffer params path
- buffer pool state prevents reuse before compositor release
- failures report typed reasons: no device, no format, allocation failed,
  export failed, import failed

## Milestone 6: EGL Render Target Probe

Goal:

- Provide the minimum EGL path needed to prove that GPU buffers can be rendered
  into and presented, without making SwiftWayland a renderer.

Work packages:

- `egl-system-target`
- `egl-display-device-selection`
- `egl-context-lifetime`
- `egl-gbm-surface-or-image-path`
- `egl-extension-validation`
- `gpu-smoke-renderer`

Required behavior:

- add system/shim targets for EGL
- create and destroy EGL displays and contexts safely
- verify required EGL extensions before enabling the GPU path
- support rendering into GBM-backed buffers or a GBM surface, depending on the
  chosen implementation route
- expose an internal render target contract that can later be backed by another
  renderer
- keep the EGL smoke renderer as a test fixture and compatibility probe, not the
  conceptual basis for public rendering APIs
- avoid public `Renderer`, `Swapchain`, or `Drawable` names until the second
  backing path validates the design
- build a tiny smoke renderer that draws a deterministic frame

Boundary:

- SwiftWayland owns presentation, buffer lifetime, protocol negotiation,
  compositor-compatible buffer constraints, synchronization, and typed
  capability/failure reporting.
- A renderer owns drawing commands, render graphs, shaders, scene composition,
  color transforms, and frame production policy.

Resource semantics:

- EGL display/context/surface/image lifetimes are explicit
- context loss and missing extension paths produce typed failures
- EGL objects do not outlive GBM buffers or devices they depend on

Exit criteria:

- a smoke executable can draw a GPU frame into a GBM/EGL target
- the frame can be converted into dmabuf plane metadata
- the implementation fails clearly when EGL is unavailable or missing required
  extensions

## Milestone 7: GPU Window Presentation

Goal:

- Present GPU-rendered buffers through managed Wayland windows.

Work packages:

- `gpu-window-backing`
- `gpu-buffer-to-wl-buffer`
- `gpu-surface-commit`
- `gpu-resize-scale-handling`
- `gpu-presentation-correlation`
- `gpu-release-lifetime`
- `gpu-live-smoke`

Required behavior:

- create a managed window with GPU backing
- render at the current buffer-pixel size derived from logical size and surface
  scale
- create dmabuf-backed `wl_buffer`s for rendered buffers
- attach, damage, and commit those buffers through the shared presenter path
- preserve configure/ack ordering
- request or correlate presentation feedback for GPU commits
- handle `wl_buffer.release` correctly
- handle resize and scale changes without reusing incompatible buffers
- recreate buffers when per-surface dmabuf feedback, output membership, color
  metadata, format/modifier selection, or sync mode changes
- keep SHM fallback available when GPU setup fails
- report all GPU path availability through scoped capabilities and typed errors

Resource semantics:

- GPU buffers are not reused until the correct release signal is observed
- release tracking works with and without explicit sync
- failed commits retire submitted buffers without leaking them
- presentation feedback correlation cannot resurrect closed windows

Exit criteria:

- live smoke proves that a GPU-rendered frame reaches a Wayland toplevel
- repeated redraws reuse only released buffers
- resize and scale changes recreate buffers as needed
- presentation feedback can be matched to GPU commits when advertised
- no raw EGL, GBM, DRM, or dmabuf details leak through normal `WaylandClient`
  APIs

## Milestone 8: Explicit GPU Synchronization

Goal:

- Add modern explicit acquire/release synchronization for GPU commits where the
  compositor supports it.

Work packages:

- `syncobj-protocol-generation`
- `syncobj-raw-layer`
- `syncobj-timeline-lifetime`
- `syncobj-surface-state`
- `syncobj-gpu-present-integration`
- `syncobj-fallback-policy`

Required behavior:

- bind `wp_linux_drm_syncobj_manager_v1` when advertised
- import DRM syncobj timelines
- create per-surface sync objects
- set acquire and release points for dmabuf commits
- respect protocol errors for missing acquire/release points
- treat `wl_buffer.release` semantics carefully when explicit sync is active
- fall back to implicit synchronization only when the compositor and driver path
  make that valid
- expose capability state that distinguishes no dmabuf, dmabuf with implicit
  sync, and dmabuf with explicit sync

Resource semantics:

- timeline fds and syncobj handles have explicit ownership
- acquire points cannot be reused incorrectly across commits
- release points control buffer reuse when explicit sync is active
- fallback from explicit to implicit sync is a deliberate runtime-path state

Exit criteria:

- explicit sync can be enabled for GPU-backed windows when advertised
- release timeline signaling controls buffer reuse in tests
- implicit-sync fallback remains available and clearly marked
- compositor behavior is validated under at least one wlroots and one
  Mutter/KWin path when available

## Milestone 9: Color And Content Metadata

Goal:

- Expose color and content metadata facts needed by renderers without making
  SwiftWayland a color pipeline.

Work packages:

- `color-management-protocol-generation`
- `color-representation-protocol-generation`
- `content-type-protocol-generation`
- `color-output-facts`
- `color-surface-metadata`
- `color-capability-model`
- `color-version-gating`

Required behavior:

- bind color-management and related metadata protocols when advertised
- provide raw output image-description and surface preferred-description
  retrieval paths for internal callers
- carry renderer-adjacent surface/content metadata through commit planning
- preserve unknown color, transfer, metadata, and rendering-intent values
- model protocol version differences, including new minor versions
- avoid assuming all future graphics paths are 8-bit sRGB-only
- keep tone mapping, gamut mapping, color conversion, and asset policy out of
  SwiftWayland

Resource semantics:

- image description objects have explicit immutable/lifetime states
- per-surface metadata is invalidated on surface destruction
- version-gated fields are not read unless advertised

Exit criteria:

- renderers can discover output and surface color facts through typed capability
  snapshots
- surface metadata can be attached or reported without exposing raw protocol
  objects
- no public API claims to perform color management or tone mapping

## Milestone 10: Public Graphics Foundation API

Goal:

- Expose GPU capability and presentation primitives without turning
  SwiftWayland into a renderer.

Work:

- decide whether GPU API lives inside `WaylandClient` or a separate preview
  product such as `WaylandGraphics`
- expose capability snapshots for SHM, dmabuf, GBM/EGL, explicit sync, and
  color/content metadata
- expose typed failure reasons for GPU setup and presentation
- expose enough surface/backing state for a higher renderer to plug in
- shape public API around submittable buffers, surface backing, or presenter
  contracts rather than renderer concepts
- keep raw graphics handles internal unless a separate expert-level product is
  created
- document fallback policy and when fallback is not allowed

Exit criteria:

- an external package can choose GPU or SHM by capability
- an external package can compile against the public graphics foundation API
- the API does not name a scene graph, view system, or renderer policy

## Milestone 11: Text Input And IME

Goal:

- Provide real text entry substrate instead of relying on local keyboard
  interpretation.

Work packages:

- `text-input-protocol-generation`
- `text-input-raw-layer`
- `text-input-version-gating`
- `text-input-focus-model`
- `text-input-public-events`
- `text-input-surrounding-text`
- `text-input-preedit-commit-delete`
- `text-input-panel-hints`
- `text-input-live-smoke`

Required behavior:

- bind `zwp_text_input_manager_v3` when advertised
- discover protocol versions and gate minor-version features
- create text input objects per seat
- model enter and leave focus
- expose enable, disable, surrounding text, content type, cursor rectangle, and
  commit state
- expose preedit, commit string, delete surrounding text, and done events
- support input panel show/hide requests when available
- preserve preedit styling and hints where available
- expose language hints and on-screen input hints where available
- preserve unknown enum and value payloads
- validate UTF-8 and byte-index rules
- make serial/order behavior explicit
- keep local keyboard text separate from protocol text input
- define unavailable behavior when the compositor has no text-input protocol

Resource semantics:

- text-input object lifetime is tied to seat and display lifetime
- enable/disable state is explicit and testable
- focus leave invalidates pending text-entry state
- ordering of preedit, commit, delete-surrounding-text, and done events is
  tested

Exit criteria:

- a higher text field can receive committed text through text-input
- preedit and deletion events are ordered according to protocol rules
- missing text-input support is visible through capabilities and typed errors
- live tests cover composition, preedit, commit string, delete-surrounding-text,
  and ordering where an IME path is available

## Milestone 12: Data Transfer And Drag Visual Completion

Goal:

- Finish desktop-grade copy, paste, and drag-and-drop substrate.

Work packages:

- `dnd-drag-icons`
- `dnd-action-policy`
- `dnd-error-diagnostics`
- `dnd-source-target-lifetime-tests`
- `data-transfer-fd-audit`

Required behavior:

- keep regular clipboard and primary selection behavior intact
- support managed drag icon surfaces
- keep icon lifetime tied to drag source lifetime
- support action negotiation, cancellation, finish, and failure paths
- keep fd closure and timeout behavior explicit
- emit useful diagnostics without event spam
- treat drag icon surfaces as tests of the shared surface role, scale, commit,
  and destruction model

Resource semantics:

- source, offer, and icon lifetimes are explicit
- pipe fds close on send, cancel, timeout, and display failure paths
- icon surfaces are destroyed on every drag source lifecycle exit

Exit criteria:

- source and target drag-and-drop work with and without icon surfaces
- all drag source lifecycle exits destroy icon resources
- data-transfer tests cover fd ownership and cancellation paths

## Milestone 13: Cursor Foundation

Goal:

- Make pointer cursors correct for mixed-DPI and ordinary desktop behavior.

Work packages:

- `cursor-config-scale-policy`
- `cursor-theme-frames`
- `cursor-output-scale-selection`
- `cursor-animation-scheduler`
- `cursor-diagnostics`
- `cursor-shape-protocol`

Required behavior:

- expose cursor scale policy
- choose cursor image scale from focused surface output context
- parse cursor theme frame sequences
- schedule animated cursor frames on the owner thread
- stop animation on focus loss, seat removal, cursor replacement, hidden cursor,
  and output scale change
- avoid stale animation commits
- support compositor-managed cursor shape protocol when advertised
- treat cursor surfaces as tests of the shared surface role, scale, commit, and
  destruction model
- keep custom cursor drawing out unless a higher framework requirement proves it

Resource semantics:

- cursor surface lifetime is tied to seat/focus state
- borrowed cursor buffers cannot outlive their theme
- animation ticks cannot commit stale buffers after focus or scale changes

Exit criteria:

- static cursor behavior remains compatible
- animated cursors advance deterministically in tests
- mixed-DPI cursor selection has deterministic policy
- missing theme data and fallback behavior produce typed diagnostics

## Milestone 14: Advanced Input

Goal:

- Cover input primitives that serious desktop apps and tools need beyond basic
  pointer, keyboard, and touch.

Candidate protocols:

- relative pointer
- pointer constraints
- tablet v2
- pointer warp as preview/use-case-gated support

Required behavior:

- expose capabilities per seat/device
- keep focus and serial rules explicit
- provide public event payloads that preserve raw protocol values where useful
- keep pointer warp out of the foundation release bar unless a concrete
  app-client use case requires it
- avoid gesture policy in SwiftWayland

Resource semantics:

- device lifetimes are tied to seats and protocol removals
- constraint/lock lifetime is explicit and cancelable
- pointer warp requests are gated by capability and use-case policy

Exit criteria:

- a higher framework can implement pointer lock, drawing tablet input, and
  precision input without raw protocol access
- unsupported protocols are reported through capabilities

## Milestone 15: Desktop Integration

Goal:

- Fill platform facts and desktop workflow gaps that ordinary apps need without
  drifting into compositor administration.

Protocol candidates:

- `xdg_activation_v1` for app launch and focus handoff
- XDG Session Management as preview/staging optional support
- `xdg_toplevel_icon_v1` for app/window identity where advertised
- `xdg_dialog_v1` or toplevel metadata only where it maps to real app flows
- `xdg_system_bell_v1` if terminal/accessibility-adjacent clients need it

Required behavior:

- expose xdg activation as a typed app-client API when implemented
- expose session-management tokens/restoration facts without owning document
  lifecycle
- expose toplevel icon and dialog metadata only as protocol-shaped desktop
  integration facts
- distinguish output observation from output control
- keep output management/control out of normal foundation scope unless a
  concrete app-client protocol need is documented
- keep compositor/admin/display-management features out of the default product

Resource semantics:

- activation/session tokens have explicit lifetime and failure states
- preview protocols carry source/API breakage policy
- app restoration facts do not imply app-framework lifecycle ownership

Exit criteria:

- app launch and focus transfer use typed APIs when compositor support exists
- output facts are enough for layout, scale, fullscreen, and diagnostics
- unsupported desktop-integration protocols have typed capability state
- output control remains out of scope unless separately justified

## Milestone 16: Diagnostics, Failure, And Resource Audit

Goal:

- Verify failure behavior is dependable enough for downstream frameworks.

Work:

- audit callback lifetime for every protocol object
- audit fd ownership for data transfer, dmabuf, keymaps, feedback tables, and
  sync objects
- audit one-shot object lifetimes
- define stream overflow behavior for every public event stream
- define display failure and reconnect expectations
- classify diagnostics by severity and operation
- test shutdown and close paths for windows, popups, data sources, cursor
  surfaces, presentation feedback, dmabuf buffers, and sync timelines
- confirm each protocol milestone has its own resource-semantics coverage

Exit criteria:

- no public operation fails with an unclassified error
- resource ownership is documented and tested
- close/shutdown behavior is covered by unit tests
- public diagnostics do not require string parsing for control flow

## Milestone 17: Compositor Compatibility Matrix

Goal:

- Treat real compositor behavior as part of the product contract.

Required targets:

- Weston headless for repeatable CI smoke
- Weston desktop where useful
- GNOME/Mutter
- KDE/KWin
- Sway/wlroots

Required scenarios:

- SHM window smoke
- surface transaction and fractional scale behavior
- presentation-time when advertised
- FIFO and commit timing when advertised
- GPU dmabuf smoke
- explicit sync when advertised
- color/content metadata when advertised
- mixed-DPI cursor behavior
- clipboard and primary selection
- source and target drag-and-drop
- text-input/IME where available
- xdg activation/session workflows where available

Exit criteria:

- optional protocols skip with exact interface names when absent
- advertised optional protocols fail tests when the tested behavior is broken
- release notes identify compositor coverage
- Weston-only behavior is never treated as complete compatibility

## Milestone 18: Swift And Linux Toolchain Contract

Goal:

- Define the Swift/Linux toolchain and system dependency assumptions for a
  foundation release candidate.

Work:

- define supported Swift toolchain range
- keep strict concurrency and strict memory-safety diagnostics as product gates
- keep generated Wayland protocol code and C shims isolated behind narrow Swift
  APIs
- evaluate Swift 6.3 C interop features such as `@c` and `@implementation` only
  where they reduce shim complexity without exposing unsafe state
- document package dependencies and ABI expectations for libwayland,
  wayland-protocols, xkbcommon, wayland-cursor, EGL, GBM, DRM, and Mesa
- keep SwiftPM and Swift Build behavior covered by CI when Swift Build becomes
  part of the supported path

Exit criteria:

- toolchain and Linux dependency expectations are documented
- unsafe C interop remains behind audited target boundaries
- generated code and shim verification are release gates

## Milestone 19: Documentation And Release Policy

Goal:

- Make the package usable by another team without reading implementation files.

Work:

- add DocC reference documentation for public API
- add conceptual docs for windowing, surface transactions, rendering,
  presentation/frame pacing, GPU backing, color metadata, text input, data
  transfer, cursor, and capabilities
- add public examples for SHM and GPU paths
- document Linux dependency packages for EGL, GBM, DRM, and Wayland protocols
- document live test setup by compositor
- define release checklist and compatibility policy
- keep public API audit current

Exit criteria:

- public docs cover every public type used by external packages
- release checklist includes source tests, live tests, public API review, and
  protocol generation verification
- downstream package examples build in CI

## Foundation Release Candidate Bar

A foundation release candidate requires all of the following:

- core xdg-shell window and popup lifecycle complete for ordinary app windows
- surface transaction model covering configure/ack/commit, surface roles,
  damage, scale, fractional scale, viewport behavior, output membership, and
  surface-scoped capability state
- output observation and scale facts sufficient for layout, fullscreen,
  diagnostics, and buffer sizing
- presentation feedback and frame-pacing primitives sufficient for renderer
  decisions
- SHM fallback retained as test baseline
- GPU path through dmabuf, GBM/EGL or equivalent allocation/render target,
  buffer release tracking, and typed fallback
- explicit sync when advertised, with clear implicit-sync fallback rules
- color/content metadata capability model that does not assume permanent 8-bit
  sRGB-only rendering
- text-input and IME substrate with version-gated behavior
- clipboard, primary selection, and drag-and-drop including drag icons
- cursor scale, animation, fallback diagnostics, and cursor-shape protocol when
  advertised
- typed capability, error, and resource-lifetime model across all optional
  protocols
- protocol phase and support-tier matrix
- live compositor matrix evidence
- public API audit, external compile tests, and DocC docs

Anything below this bar can be a development checkpoint, but not the foundation
target this roadmap is describing.

## Active Sprint Adjustment

Keep the current presentation-time sprint as the active first milestone:

- `docs-dnd-presentation-state`
- `presentation-protocol-generation`
- `presentation-raw-layer`
- `presentation-client-state`
- `presentation-public-api`
- `presentation-live-smoke`

Move the current cursor/DnD visual sprint behind the GPU foundation work unless
there is parallel capacity that does not slow the GPU path:

- `cursor-config-scale-policy`
- `cursor-theme-frames`
- `cursor-output-scale-selection`
- `cursor-animation-scheduler`
- `cursor-diagnostics`
- `dnd-drag-icons`

The replacement second milestone should be GPU substrate:

- `surface-transaction-model`
- `dmabuf-protocol-generation`
- `dmabuf-raw-layer`
- `dmabuf-feedback-model`
- `gbm-system-target`
- `egl-system-target`
- `gpu-device-selection`
- `gpu-buffer-lifecycle`
- `gpu-window-backing`
- `gpu-live-smoke`
