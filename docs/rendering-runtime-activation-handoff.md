# Rendering Runtime Activation Handoff

Status date: 2026-06-13

Branch: `complete-rendering-runtime-sprints`

Base: `main` after the rendering runtime activation work was merged.

## Scope

This handoff covers the connected rendering/runtime track:

- Explicit synchronization activation.
- FIFO and commit-timing frame pacing.
- Surface metadata activation.

The implementation is already in the repository baseline. This branch records
the refreshed live runtime evidence and aligns status documentation with the
current compositor facts.

## Sprint 1: Explicit Synchronization

Status: implemented and live-proven active on KDE/KWin.

What is in place:

- `implicitOnly` avoids explicit sync objects.
- `preferExplicit` attempts linux-drm-syncobj on the managed GPU path.
- `preferExplicit` can fall back before explicit sync is installed on a
  surface.
- Once explicit synchronization is configured or active on a surface, implicit
  software fallback is rejected instead of silently committing an implicit
  frame.
- `requireExplicit` does not silently fall back, including software backing and
  forced software configurations.
- Explicit release waits are decoupled from the just-committed submission and
  enforced when deciding whether a submitted slot can be reused.
- Release timelines are separate from acquire timelines so client-side acquire
  signaling cannot make compositor-owned release points appear complete.
- Post-commit presenter failures are surfaced as committed-frame failures so a
  committed frame is not rolled back into a software retry.
- Reconfigure teardown drops old render targets before destroying the GBM
  device.

Live evidence:

- `swift run GPUPreviewSmokeClient -- --sync prefer-explicit --pacing fifo`
  reported `explicit sync: advertised v1, runtime active`, `fifo: active`,
  `backing: gpu active`, `fallback reason: none`, and `failure: none`.
- `swift run GPUPreviewSmokeClient -- --sync require-explicit` reported
  `explicit sync: advertised v1, runtime active`, `backing: gpu active`,
  `fallback reason: none`, and `failure: none`.

Remaining evidence work:

- Broaden explicit-sync active evidence beyond the local KDE/KWin session.

## Sprint 2: FIFO And Commit Timing

Status: FIFO implemented and live-proven active; commit timing implemented with
typed fallback/failure reporting, but not live-proven active on the current
KDE/KWin compositor because the protocol is not advertised.

What is in place:

- `none` preserves the current submit behavior.
- `preferFIFO` applies FIFO submit constraints on managed GPU, direct software,
  and allowed software fallback commits when available.
- FIFO commits prime the compositor with `set_barrier` before later commits
  wait on the previous barrier and set the next barrier.
- `preferCommitTiming` applies commit-timing constraints when the protocol is
  available.
- Missing FIFO or commit-timing support reports typed fallback facts instead of
  pretending the request was active.
- Commit-timing timestamp rejection maps to a typed failure.
- Runtime status distinguishes advertised, active, fallback, and failed states
  per pacing feature.

Live evidence:

- `swift run GPUPreviewSmokeClient -- --sync prefer-explicit --pacing fifo`
  reported FIFO active on a committed managed GPU frame.
- `swift run GPUPreviewSmokeClient -- --pacing commit-timing` reported
  `commit timing: fallback(commitTimingUnavailable)` with active GPU backing.
- `wayland-info` on the same KDE/KWin session did not advertise
  `wp_commit_timing_manager_v1`.

Remaining evidence work:

- Collect active commit-timing evidence on a compositor that advertises commit
  timing and can reach active managed GPU backing.

## Sprint 3: Surface Metadata

Status: content type and presentation-hint/tearing metadata are implemented and
live-proven active on KDE/KWin; color representation and color management remain
runtime facts rather than renderer policy.

What is in place:

- `metadataPolicy: .none` rejects non-default public metadata.
- `metadataPolicy: .preferAvailable` applies supported metadata and omits
  unavailable preferred metadata with typed runtime fallback reasons.
- Content type maps through package-internal surface commit metadata when the
  protocol is available.
- Presentation hint maps to tearing-control metadata where available and remains
  a hint, not a guarantee.
- Metadata validation happens before commit requests consume the frame lease.
- Metadata failures do not dirty later commits.
- Software and managed GPU paths carry the same public metadata policy shape.
- Public API stays renderer-neutral and does not expose raw color-management
  objects.

Live evidence:

- `swift run GraphicsPreviewManagedGPUClear -- --sync prefer-explicit --pacing fifo --metadata prefer --content-type game --presentation-hint async --auto-close --print-summary`
  submitted five frames and reported explicit sync active, FIFO active, content
  type active, tearing control active, actual backing `managedGPU`, fallback
  reason `none`, and failure `none`.

Remaining evidence work:

- Broaden metadata evidence beyond KDE/KWin.
- Keep color representation and color-management facts documented as protocol
  facts until a renderer-facing policy is intentionally designed.

## Public API Boundary

- Package branding is `WaylandClientKit`.
- The main public substrate product remains `WaylandClient`.
- Preview graphics users opt into `WaylandGraphicsPreview`.
- The preview API remains source-breaking while the graphics foundation is
  still under development.
- No public raw Wayland, GBM, EGL, DRM, dmabuf, syncobj, file descriptor, or C
  shim handles are introduced by the graphics preview API.

## Updated Evidence Documents

- `docs/compositor-matrix.md`
- `docs/foundation-candidate-status.md`
- `docs/foundation-evidence-report.md`
- `docs/graphics-preview-api.md`
- `docs/public-api-audit.md`
- `docs/roadmap.md`
- `Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/ManagedGPUPreview.md`

## Validation Run

- `swift run GPUPreviewSmokeClient -- --sync prefer-explicit --pacing fifo`
- `swift run GPUPreviewSmokeClient -- --sync require-explicit`
- `swift run GPUPreviewSmokeClient -- --pacing commit-timing`
- `swift run GraphicsPreviewManagedGPUClear -- --sync prefer-explicit --pacing fifo --metadata prefer --content-type game --presentation-hint async --auto-close --print-summary`
- `swift run GraphicsPreviewManagedGPUClear -- --pacing commit-timing --auto-close --print-summary`
- `wayland-info` protocol check for syncobj, FIFO, commit timing, dmabuf,
  presentation, tearing, content type, color representation, and color
  management globals.
- `git diff --check`
- `swift run swl docs verify`
- `swift run swl docc verify`
- `swift run swl compositor evidence-summary`
- `swift run swl ci cheap`
- `swift run swl ci check`
- `swift run swl examples build`

## Merge Notes

The remaining open item is not a code-path blocker for these sprints: commit
timing still needs active evidence on a compositor that advertises it. The
current local compositor does not advertise commit timing, and the runtime path
truthfully reports `fallback(commitTimingUnavailable)`.
