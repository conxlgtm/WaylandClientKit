# Foundation Candidate Status

SwiftWayland is not yet a foundation release candidate.

## Current Product Shape

- `WaylandClient` is the main public app-substrate product.
- `WaylandGraphicsPreview` is a source-breaking preview product for
  renderer-neutral graphics backing experiments.
- `WaylandGPUPreview` and `WaylandGraphicsCore` are package-internal
  implementation targets, not public products.

## Managed GPU Status

Implemented:

- `.software` backing stays on the software path and does not attempt GPU setup.
- `.managedGPU` attempts package-internal GPU setup for clear-frame submission:
  per-surface dmabuf feedback, compatible format/modifier selection, render-node
  selection, GBM device and surface allocation, EGL/GLES clear rendering, dmabuf
  import, and owner-thread surface commit.
- Fallback-allowed managed GPU submissions fall back to software with a typed
  public reason.
- `requireGPU` managed GPU submissions fail with a typed public unavailable
  reason instead of silently falling back.
- Runtime paths distinguish advertised, configured, active, fallback, failed,
  and unavailable states. Active GPU is reported only after a GPU-rendered buffer
  is imported and committed.

Not yet proven:

- Active managed GPU backing on a live desktop compositor.
- Active managed GPU backing under headless Weston.
- Explicit sync, FIFO, and commit-timing activation on real compositors.
- Broad resize/reconfiguration behavior for GPU buffers.

## Current Blockers

- Fresh compositor matrix rows for managed GPU preview on at least one desktop
  compositor and headless Weston.
- Optional live rows for Sway/wlroots and a second desktop compositor.
- Runtime evidence for explicit-sync and pacing behavior where advertised.
- Continued public API audit and baseline review for preview product drift.

## Required Validation Gates

- `swift run swl ci check`
- `swift run swl ci release`
- `swift run swl examples build`
- `swift run swl api verify`
- `swift run swl docs verify`
- `swift run swl docc verify`
- `swift run swl imports verify`
- `swift run swl shims verify`
- `swift run swl shims verify-release-symbols`
- `swift run swl safety verify-unsafe-allowlist`
- `swift run swl protocols verify-generated`
- `swift run swl compositor evidence-summary`

Live compositor checks are required before changing this status to foundation
candidate. Environment skips should name the missing compositor, GPU, render
node, or protocol.
