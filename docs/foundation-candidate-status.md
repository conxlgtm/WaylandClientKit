# Foundation Candidate Status

Status: not a foundation release candidate.

SwiftWayland has a credible public substrate shape, but foundation status still
depends on documentation coverage, compatibility policy discipline, release
gates, and broader live compositor evidence. Managed GPU code presence is not
enough; active GPU claims must be backed by public runtime-path output.

## Status Labels

- `done`: implemented, documented, and covered by normal validation.
- `partial`: implemented or documented, but evidence or coverage is incomplete.
- `missing`: not present yet.
- `blocked-by-compositor-evidence`: needs live compositor output.
- `blocked-by-docs`: behavior exists but public docs are incomplete.
- `blocked-by-policy`: policy or release gates do not yet enforce the claim.

## Checklist

| Area | Status | Evidence | Next action |
| --- | --- | --- | --- |
| Public API audit and baseline | done | [public-api-audit.md](public-api-audit.md), [public-api-baseline.md](public-api-baseline.md), `swift run swl api verify` | Keep both updated for every public drift. |
| Compatibility policy | done | [compatibility-policy.md](compatibility-policy.md) | Apply tiers during PR review. |
| WaylandClient compatibility tier | partial | Main public product is documented as stable-ish but pre-foundation. | Keep source-breaking changes audited and documented. |
| WaylandGraphicsPreview preview tier | partial | Preview policy documented in [compatibility-policy.md](compatibility-policy.md) and DocC. | Keep preview drift baseline/audit tracked. |
| DocC coverage | partial | `WaylandClient` and `WaylandGraphicsPreview` catalogs exist. | Run `swift run swl docc verify` after public API/doc changes. |
| User learning path | done | [getting-started.md](getting-started.md), [which-api-should-i-use.md](which-api-should-i-use.md), [documentation-map.md](documentation-map.md) | Keep README as portal, not full manual. |
| Managed GPU setup code path | done | Managed GPU attempts surface feedback, render-node, GBM/EGL, dmabuf import, owner-thread commit, and typed fallback. | Keep runtime-path truth tests current. |
| Managed GPU active proof | partial | [compositor-matrix.md](compositor-matrix.md) records active managed GPU clear-frame submission on KDE/KWin and `dmabufUnavailable` fallback under headless Weston. | Add at least one more desktop or wlroots active/fallback/failure row before foundation-candidate claims. |
| Compositor matrix minimum | done | [compositor-matrix.md](compositor-matrix.md) records headless Weston plus KDE/KWin rows and separates protocol advertisement from active runtime facts. | Keep GNOME/Mutter and Sway/wlroots rows current when those sessions are available. |
| External consumer evidence | partial | Public and graphics preview integration clients are part of `swl ci check`. | Keep external clients hardware-independent. |
| Release checks | partial | `swift run swl ci release`, `swift run swl examples build`, release docs. | Keep release gates runnable while evidence remains incomplete. |
| Foundation-candidate gate | partial | `swift run swl ci foundation-check` fails while the compositor matrix has pending, not-tested, or not-run cells. | Complete or explicitly skip remaining compositor evidence before claiming foundation readiness. |
| Sanitizer checks | partial | TSan/ASan commands documented in [release.md](release.md). | Run where environment supports them and record skips. |
| Toolchain baseline | done | `swift run swl tools toolchain-smoke`; Swift 6.3.2 required baseline. | Keep 6.4/main snapshots optional and allowed-failure. |
| Known non-goals | done | README, DocC, compatibility policy. | Keep widgets, layout, renderer abstraction, scene graph, styling, and accessibility semantic tree out of scope. |

## Managed GPU Status

Implemented:

- `.software` backing stays on the software path and never attempts GPU setup.
- `.managedGPU` attempts package-internal GPU setup for clear-frame submission:
  per-surface dmabuf feedback, compatible format/modifier selection, render-node
  selection, GBM device and surface allocation, EGL/GLES clear rendering, dmabuf
  import, owner-thread surface commit, and buffer release/reuse tracking.
- Fallback-allowed managed GPU submissions fall back to software with a typed
  public reason.
- `requireGPU` managed GPU submissions fail with a typed public unavailable
  reason instead of silently falling back.
- Runtime paths distinguish advertised, configured, active, fallback, failed,
  and unavailable states. Active GPU is reported only after a GPU-rendered buffer
  is imported and committed.

Still needs broader evidence:

- Active managed GPU backing beyond the current KDE/KWin run.
- Managed GPU behavior on GNOME/Mutter and Sway/wlroots.
- Active managed GPU backing under headless Weston is not expected while dmabuf
  is unavailable there; keep the typed fallback row current.
- Explicit sync, FIFO, and commit-timing activation on real compositors.
- Broad live resize/reconfiguration behavior for GPU buffers.

## Required Commands

Normal readiness:

```bash
swift run swl tools toolchain-smoke
swift run swl ci check
swift run swl ci release
swift run swl examples build
swift run swl api verify
swift run swl docs verify
swift run swl docc verify
swift run swl imports verify
swift run swl shims verify
swift run swl shims verify-release-symbols
swift run swl safety verify-unsafe-allowlist
swift run swl protocols verify-generated
swift run swl compositor evidence-summary
```

Foundation-candidate readiness:

```bash
swift run swl ci foundation-check
```

Live evidence:

```bash
swift run swl smoke live
swift run swl smoke integration
swift run GPUPreviewSmokeClient
swift run GraphicsPreviewManagedGPUClear
```

Environment skips must name the missing compositor, GPU, render node, protocol,
or sanitizer support. Do not mark a row `done` from code inspection alone.
