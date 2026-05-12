# Next Platform Work Plan

Status: active near-term plan  
Date: 2026-05-12  
Planning horizon: the next two working weeks after the presentation-time merge

This document turns the updated platform roadmap into immediate work. The goal
is to land the presentation-time branch, then move directly into the shared
surface transaction model that will support SHM, GPU buffers, cursor surfaces,
drag icons, popups, fractional scale, presentation feedback, and explicit sync.

## Objective

SwiftWayland should leave the current presentation-time branch with a clean
platform checkpoint:

- `wp_presentation` is vendored, generated, exposed, documented, and tested.
- `docs/roadmap.md` records the long-range foundation bar.
- The next engineering target is surface transaction semantics, not cursor/DnD
  visual work.
- GPU work starts only after the surface model has a place for non-SHM buffers.

The next couple of weeks should produce an internal shape where a GPU presenter
can be added without forking the whole window lifecycle.

## Merge Checkpoint

Branch:

- Source branch: `presentation-time-substrate`
- Local target branch: `main`
- Merge route: local fast-forward after validation
- Push or pull request: separate explicit step after the local merge

Before merging:

- Force-add ignored planning docs:
  - `docs/roadmap.md`
  - `docs/next-platform-work-plan-2026-05.md`
- Commit the planning docs with the subject:
  - `Document platform foundation roadmap`
- Run:
  - `make check`
- Run when Weston is available or required for the checkpoint:
  - `make wayland-headless`
- Optionally generate a public API dump for review:
  - `./scripts/ci/dump-public-api.sh > /tmp/swiftwayland-public-api.md`

Merge steps:

```bash
git switch main
git merge --ff-only presentation-time-substrate
make check
```

Stop conditions:

- generated protocol verification fails
- shim verification fails
- strict concurrency build fails
- unit tests fail
- public API client tests fail
- live/headless tests fail for an advertised protocol path
- docs and README disagree about presentation-time support

## Workstream 1: Presentation-Time Closeout

Purpose:

- Finish the presentation-time checkpoint and make it ready for follow-on
  surface/GPU work.

Work packages:

- `presentation-live-smoke`
- `presentation-public-api-audit`
- `presentation-docs-alignment`
- `presentation-release-notes-scope`

Required results:

- `WaylandDisplay.capabilities()` reports `wp_presentation` availability.
- Managed windows can request presentation feedback.
- Presented and discarded feedback publish through typed public events.
- Missing `wp_presentation` reports unavailable and live tests skip with the
  exact interface name.
- Advertised but broken presentation feedback is a test failure.
- Frame callbacks remain separate from presentation feedback.
- Public docs say presentation feedback is not a renderer, scheduler, or fake
  frame callback timestamp.

Acceptance checks:

- `make check`
- `make wayland-headless` when Weston is available
- public API dump reviewed for new presentation symbols

## Workstream 2: Surface Transaction Model

Purpose:

- Create the internal surface-state model that future GPU, cursor, drag icon,
  popup, and fractional-scale work can share.

Candidate branch:

- `surface-transaction-model`

Work packages:

- `surface-role-invariants`
- `surface-transaction-model`
- `fractional-scale-contract`
- `viewport-scale-commit-plan`
- `damage-region-semantics`
- `surface-output-membership`
- `surface-capability-snapshots`
- `surface-resource-state-tests`

Required results:

- Configure, ack, and commit ordering are represented explicitly.
- Surface roles are represented so a surface cannot be reused as another role.
- Logical size, buffer-pixel size, integer scale, fractional scale, and viewport
  destination are represented in one commit plan.
- Fractional scale keeps `wl_surface` buffer scale at 1 and uses viewporter
  destination to map buffer pixels back to logical size.
- Damage region coordinate space is explicit: buffer damage versus logical
  damage.
- Surface output membership is available to commit planning and cursor scale
  policy.
- Surface-scoped capability snapshots exist internally for fractional scale,
  presentation availability, output membership, future dmabuf feedback, future
  color metadata, and future sync mode.
- Surface destruction invalidates pending presentation feedback, cursor state,
  drag icon state, future dmabuf feedback, and future sync objects.

Public API rule:

- No new public renderer, swapchain, drawable, or scene API.
- Keep public surface changes minimal unless a capability fact must be visible
  to downstream code.

Acceptance checks:

- Existing SHM window and popup behavior remains compatible.
- Tests cover integer scale, fractional scale, viewport destination, damage
  coordinate selection, output enter/leave, and surface destruction.
- Existing presentation feedback tests still pass.
- Internal API has a clear attach point for non-SHM buffers.

## Workstream 3: Presenter Boundary

Purpose:

- Split software drawing from surface commit behavior so GPU buffers can later
  use the same window lifecycle.

Candidate branch:

- `surface-presenter-boundary`

Work packages:

- `software-presenter-extraction`
- `shared-surface-commit-planner`
- `presenter-buffer-lifecycle`
- `presenter-close-state-tests`

Required results:

- SHM `SoftwareFrame` remains the only public drawing path for now.
- SHM drawing becomes one internal presenter.
- Shared commit code owns scale installation, damage, frame callback requests,
  presentation feedback hooks, and surface commit.
- Presenter states cover drawing, submitted, released, retired, failed, and
  closed.
- Close while drawing, close while submitted, release after close, and draw
  failure are tested.

Public API rule:

- Do not rename `SoftwareFrame` into a generic drawing type.
- Do not expose a GPU presenter publicly in this workstream.

Acceptance checks:

- `Window.show` and `Window.redraw` keep their current public signatures.
- SHM buffer release and redraw scheduling tests still pass.
- A future presenter can provide a non-SHM `wl_buffer` without duplicating
  configure/scale/presentation logic.

## Workstream 4: Dmabuf Protocol Groundwork

Purpose:

- Start GPU foundation work after the surface transaction model has an internal
  place for per-surface capabilities and non-SHM buffers.

Candidate branch:

- `dmabuf-protocol-generation`

Work packages:

- `dmabuf-protocol-generation`
- `dmabuf-raw-layer`
- `dmabuf-feedback-model`
- `dmabuf-buffer-params-lifecycle`
- `dmabuf-capability-reporting`

Required results:

- Vendor `linux-dmabuf` protocol XML and record upstream phase/tier in the
  protocol manifest.
- Generate protocol C/header artifacts and request/listener shims.
- Bind `zwp_linux_dmabuf_v1` as optional capability.
- Model default feedback and per-surface feedback separately.
- Parse format table fds through read-only mapping.
- Model main device, target device, tranche flags, and format/modifier pairs.
- Preserve unknown flags and modifiers.
- Model `zwp_linux_buffer_params_v1` as pending, created, failed, and destroyed.
- Close all fds on failure paths.

Public API rule:

- Do not expose raw dmabuf, GBM, EGL, DRM, or fd-heavy APIs as ordinary
  `WaylandClient` product surface.
- Expose only capability facts if needed before the managed GPU path exists.

Acceptance checks:

- Generated source and shim verification pass.
- Unit tests cover feedback table parsing and params object lifetime.
- Live tests skip with the exact missing `zwp_linux_dmabuf_v1` name.

## Deferred Work

These remain important, but should not block the GPU foundation path unless
there is parallel capacity:

- `cursor-config-scale-policy`
- `cursor-theme-frames`
- `cursor-output-scale-selection`
- `cursor-animation-scheduler`
- `cursor-diagnostics`
- `dnd-drag-icons`

Cursor and drag icon work should resume after the surface transaction model is
in place because both depend on surface roles, scale, output membership, commit
ordering, and destruction behavior.

## Validation Gates

Run before merging each workstream:

```bash
make check
```

Run when the workstream touches live Wayland behavior:

```bash
make wayland-headless
```

Run before checkpoint notes or release notes:

```bash
./scripts/ci/dump-public-api.sh > /tmp/swiftwayland-public-api.md
```

A workstream is not ready if:

- public API and `docs/public-api-audit.md` disagree
- README support lists disagree with implemented behavior
- generated protocol artifacts are stale
- shim verification is stale
- optional protocol absence is reported as an error during normal baseline use
- an advertised optional protocol path silently skips instead of failing

