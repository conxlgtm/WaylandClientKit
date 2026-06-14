# Foundation Candidate Status

Status: not a foundation release candidate.

WaylandClientKit has a credible public substrate shape, but foundation status still
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
| Public API audit and baseline | done | [public-api-audit.md](public-api-audit.md), [public-api-baseline.md](public-api-baseline.md), `swift run wck api verify` | Keep both updated for every public drift. |
| Compatibility policy | done | [compatibility-policy.md](compatibility-policy.md) | Apply tiers during PR review. |
| WaylandClient compatibility tier | partial | Main public product is documented as stable-ish but pre-foundation. | Keep source-breaking changes audited and documented. |
| WaylandGraphicsPreview preview tier | partial | Preview policy documented in [compatibility-policy.md](compatibility-policy.md) and DocC. | Keep preview drift baseline/audit tracked. |
| DocC coverage | partial | `WaylandClient` and `WaylandGraphicsPreview` catalogs exist. | Run `swift run wck docc verify` after public API/doc changes. |
| User learning path | done | [getting-started.md](getting-started.md), [which-api-should-i-use.md](which-api-should-i-use.md), [documentation-map.md](documentation-map.md) | Keep README as portal, not full manual. |
| Session readiness | done | [session-readiness.md](session-readiness.md), [session-management-plan.md](session-management-plan.md), `SessionStateSmoke`, `CompositorSessionSmoke`, `WindowRestorationSnapshot` | Keep compositor session-management public API capability-only until lifecycle evidence and framework usage shape are clear. |
| Managed GPU setup code path | done | Managed GPU attempts surface feedback, render-node, GBM/EGL, dmabuf import, owner-thread commit, and typed fallback. | Keep runtime-path truth tests current. |
| Managed GPU active proof | partial | [compositor-matrix.md](compositor-matrix.md) records active managed GPU clear-frame submission and resize/reconfigure on KDE/KWin, active managed GPU clear-frame submission on nested Sway/wlroots, `surfaceFeedbackUnavailable` fallback on GNOME/Mutter, and `dmabufUnavailable` fallback under headless Weston. | Broaden active/fallback/failure evidence before foundation-candidate claims, especially another desktop compositor when active managed GPU is available. |
| Compositor matrix minimum | partial | [compositor-matrix.md](compositor-matrix.md) records fresh headless Weston, KDE/KWin, nested Sway/wlroots, and GNOME/Mutter VM rows and separates protocol advertisement from active runtime facts. KDE/KWin now has manual proof for pointer lock/confine with relative motion, data-transfer drag-source/drop/read/finish, serial move/window-menu/resize/drag-source, managed GPU resize/reconfigure, explicit sync active, FIFO active, and metadata active. | Complete remaining GNOME/Mutter manual rows, popup-specific manual probes, broader explicit-sync compositor evidence beyond KDE/KWin, and commit-timing active evidence where practical. |
| External consumer evidence | partial | Public and graphics preview integration clients are part of `wck ci check`. | Keep external clients hardware-independent. |
| Release checks | partial | `swift run wck ci release`, `swift run wck examples build`, release docs. | Keep release gates runnable while evidence remains incomplete. |
| Foundation-candidate gate | partial | `swift run wck ci foundation-check` fails while the compositor matrix has incomplete cells, explicit environment skips, or manual-interaction gaps. | Complete remaining compositor and interaction evidence before claiming foundation readiness. |
| Sanitizer checks | partial | 2026-06-09 pass recorded TSan and ASan `detect_leaks=0` passes; LSan was unusable in this environment during SwiftPM test discovery. | Keep TSan/ASan current and rerun LSan in an environment where LeakSanitizer works. |
| Toolchain baseline | done | `swift run wck tools toolchain-smoke`; Swift 6.3.2 required baseline. | Keep 6.4/main snapshots optional and allowed-failure. |
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

- Active managed GPU on GNOME/Mutter was not proven; the current GNOME VM row
  records typed software fallback `surfaceFeedbackUnavailable`.
- Active managed GPU backing under headless Weston is not expected while dmabuf
  is unavailable there; keep the typed fallback row current.
- Broader explicit-sync evidence beyond KDE/KWin and commit-timing active
  evidence on real compositors. FIFO and explicit sync have active KDE/KWin
  evidence; commit timing reports typed fallback where unavailable and still
  needs active compositor evidence.
- Broad live resize/reconfiguration behavior for GPU buffers.

## 2026-06-09 Evidence Pass

Ran under Swift 6.3.2. KDE/KWin on `wayland-0` advertised dmabuf v5,
linux-drm-syncobj v1, FIFO v1, presentation v2, text-input v3 v1,
cursor-shape v2, pointer constraints v1, relative pointer v1, top-level icon
v1, idle inhibit v1, system bell v1, xdg activation v1, and color metadata.
Commit timing was unavailable. Nested Sway/wlroots on `wayland-1` advertised
dmabuf v4, linux-drm-syncobj v1, presentation v2, text-input v3 v1,
cursor-shape v1, pointer constraints v1, relative pointer v1, idle inhibit v1,
xdg activation v1, and content type, alpha, and tearing metadata.

KDE/KWin passed `wck smoke live`, `wck smoke integration`, `wck smoke
gpu-preview`, `wck examples build`, the graphics preview examples, and the
bounded auto-close feature smoke targets listed in
[compositor-matrix.md](compositor-matrix.md). Managed GPU clear-frame
submission reported active. `swift run wck ci check` was attempted on KDE/KWin
but hung after building `wck` with no child process and no further output.

A 2026-06-13 graphics preview refresh on the same KDE/KWin session reported
`preferExplicit` and `requireExplicit` as explicit-sync active with GPU backing
active, FIFO active when requested, content type and tearing-control metadata
active when requested, and commit timing
`fallback(commitTimingUnavailable)` because the compositor did not advertise the
commit-timing protocol.

Nested Sway/wlroots passed `wck smoke live`, `wck smoke integration`, `wck smoke
gpu-preview`, and both graphics preview examples. Managed GPU clear-frame
submission reported active in the nested session.

Headless Weston passed live, integration, GPU preview, and the bounded feature
loop. Managed GPU correctly fell back with `dmabufUnavailable`.

GNOME/Mutter evidence was added from a Fedora GNOME Wayland VM on 2026-06-11.
The VM passed `wck smoke live`, `wck smoke integration`, `wck smoke
gpu-preview`, `GPUPreviewSmokeClient`, and `GraphicsPreviewManagedGPUClear`.
GNOME advertised dmabuf v3, presentation v2, FIFO v1, commit timing v1,
text-input v3 v1, cursor-shape v2, pointer constraints v1, relative pointer v1,
idle inhibit v1, system bell v1, xdg activation v1, color management v2, and
color representation v1. The managed GPU examples reported software fallback
`surfaceFeedbackUnavailable`; active GPU was not proven on GNOME.

TSan and ASan with leak detection disabled passed. LSan was unusable in this
environment because SwiftPM test discovery terminated with a LeakSanitizer fatal
error during `--dump-tests-json`.

Manual serial-sensitive resize/drag-source actions and managed GPU
resize/reconfigure remain unproven.

## Required Commands

Normal readiness:

```bash
swift run wck tools toolchain-smoke
swift run wck ci check
swift run wck ci release
swift run wck examples build
swift run wck api verify
swift run wck docs verify
swift run wck docc verify
swift run wck imports verify
swift run wck shims verify
swift run wck shims verify-release-symbols
swift run wck safety verify-unsafe-allowlist
swift run wck protocols verify-generated
swift run wck compositor evidence-summary
```

Foundation-candidate readiness:

```bash
swift run wck ci foundation-check
```

Live evidence:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run GPUPreviewSmokeClient
swift run GraphicsPreviewManagedGPUClear -- --auto-close --print-summary
```

Environment skips must name the missing compositor, GPU, render node, protocol,
or sanitizer support. Do not mark a row `done` from code inspection alone.
