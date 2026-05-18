# Surface Submit Readiness And Timing

This branch records the next two-sprint workstream for SwiftWayland surface
submits. The theme is buffer readiness, latch eligibility, and buffer reuse.

## Sprint 1: Surface Submit Constraints

Goal: add internal protocol and surface-state substrate for explicit sync, FIFO,
and commit timing without adding public GPU, renderer, swapchain, or scheduling
API.

Work items:

- Add vendored protocol XML, generated artifacts, and manifest metadata for
  `linux-drm-syncobj-v1`, `fifo-v1`, and `commit-timing-v1`.
- Add raw wrappers for linux-drm-syncobj manager, surface, timeline, timeline fd,
  and timeline points.
- Add raw wrappers for FIFO and commit-timing manager/surface objects.
- Add a unified `SurfaceSubmitConstraints` value model that represents
  synchronization and pacing constraints together.
- Extend `SurfaceRuntime` capability snapshots with synchronization and pacing
  capability facts.
- Carry submit constraints through surface frame commit preparation, defaulting
  existing call sites to implicit sync and no pacing.
- Add typed validation for illegal constraint/capability combinations before raw
  protocol requests.
- Teach compositor fact collection to report syncobj, FIFO, and commit-timing
  advertisement.

Exit criteria:

- The three protocols are generated and manifest-tracked.
- Raw wrappers and request shims have unit/contract tests.
- `SurfaceRuntime` reports synchronization and pacing capabilities.
- Surface commit requests can carry default and non-default submit constraints.
- Constraint validation is typed and internal.
- Existing SHM, cursor, drag icon, popup, window, and GPU preview behavior stays
  on the implicit/default path.

## Sprint 2: GPU Submit Pipeline Integration

Goal: use the Sprint 1 submit-constraint model inside the package-internal GPU
path so the presenter can reason about buffer readiness, commit pacing, and
reuse policy. This remains package-internal.

Work items:

- Add GPU synchronization mode and synchronization policy values.
- Track release timeline ownership per submitted buffer.
- Extend GPU presenter state so implicit and explicit submissions have distinct
  reuse rules.
- Pass `SurfaceSubmitConstraints` through GPU preview commits.
- Add internal FIFO and commit-timing policy values for GPU submits.
- Associate presentation feedback with GPU slot submissions.
- Add an internal runtime path snapshot for dmabuf, GBM, EGL, sync, pacing, and
  presentation feedback status.
- Make GPU preview smoke report implicit, explicit, FIFO, and commit-timing path
  results when those optional protocols are advertised.

Exit criteria:

- GPU preview can run through implicit sync as today.
- Explicit sync mode does not treat `wl_buffer.release` as enough proof for
  buffer reuse.
- FIFO and commit-timing constraints can be attached internally.
- Optional path absence is reported as a capability fact, not a public API
  failure.
- No public GPU rendering API is introduced.

