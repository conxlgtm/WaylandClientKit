# Development Checkpoint Checklist

Tags are reproducible development checkpoints. They do not imply API stability.
Do not tag while docs, public API audit, support lists, and checks disagree.
Review [compositor-matrix.md](compositor-matrix.md) before claiming managed GPU
or foundation-candidate readiness.
Review [compatibility-policy.md](compatibility-policy.md) before tagging any
checkpoint with public API changes.

## Required Checks

Run these from a clean working tree:

```bash
swift run wck tools toolchain-smoke
swift run wck ci release
swift run wck examples build
swift run wck compositor evidence-summary
swift run wck api dump
```

`swift run wck ci release` covers the release build path, release tests, shim
checks, generated protocol freshness, DocC verification, public API audit
verification, and Wayland checks when a compositor or Weston is available.

`swift run wck compositor evidence-summary` summarizes the current compositor
matrix so missing live evidence stays visible during checkpoint review. It is a
release review aid, not proof of foundation readiness.

`swift run wck ci foundation-check` is intentionally stricter than the ordinary
release gate. Run it only when evaluating a foundation-candidate claim. It fails
when the compositor matrix still contains incomplete cells, explicit
environment skips, or manual-interaction gaps, so missing live evidence cannot
be mistaken for foundation readiness.

`swift run wck test release` runs the release-compatible test subset. Shim-contract and
instrumentation tests that depend on debug-only C or Swift test hooks are
compile-gated out of release test binaries so production release products do
not expose those symbols.

Where the environment supports Swift sanitizers, also run:

```bash
swift run wck test tsan
ASAN_OPTIONS=detect_leaks=0 swift run wck test asan
swift run wck smoke headless -- wck test request-paths
swift run wck smoke headless -- wck test request-paths-tsan
swift run wck smoke headless -- wck test request-paths-asan
swift run wck smoke headless -- wck smoke integration
swift test --filter WaylandThreadExecutorConcurrencyTests --no-parallel
```

ThreadSanitizer is the primary concurrency lifecycle check. AddressSanitizer
with `detect_leaks=0` is the required ASan gate. LeakSanitizer remains a
separate informational check because it can exit with a ptrace-related fatal
error even after the Swift test process reports passing tests, record that as
an environment limitation rather than a test failure. To attempt the
LeakSanitizer path explicitly, run `swift run wck test asan` without setting
`ASAN_OPTIONS=detect_leaks=0`. The TSan target uses
`safety/tsan-suppressions.txt` only for known Swift runtime
metadata-cache and Swift Testing event graph reports. It also disables TSan's
deadlock detector because Swift runtime metadata initialization currently
produces lock-order false positives. The target runs Swift Testing with
parallel execution disabled so sanitizer output is not polluted by unrelated
test-runner and runtime parallel initialization reports, project data-race
reports inside tests should remain unsuppressed.

The hosted TSan job runs the Swift 6.3.2 Noble container on an Ubuntu 22.04
host. The container uses an unconfined seccomp profile so `setarch` can give
each sanitizer process a fixed address layout before Swift starts. The TSan
command builds the package test bundle, then runs that bundle directly instead
of relying on SwiftPM's combined build-and-run launcher, which can exit after
linking without starting the large test bundle on hosted runners. Compilation
is limited to two jobs to bound peak memory. A small instrumented runtime probe
runs before the package suite so a future runner regression fails before the
long sanitizer build.

The public API baseline covers both vended library products, `WaylandClient`
and `WaylandGraphicsPreview`. Preview API drift should still be reviewed and
reflected in the audit and baseline before tagging.

The headless request-path sanitizer targets run the window-control and
source-side drag request tests under a private Weston compositor. They are the
release gate for live request wrappers under sanitizers. GPU preview sanitizer
smoke remains optional and compositor/hardware dependent, use
`WAYLAND_CLIENT_KIT_ENABLE_GPU_PREVIEW_TESTS=1` under a known GPU-capable session
when collecting compositor matrix facts. The request-path targets default to a
600 second timeout because sanitizer builds can spend several minutes compiling
before tests start, override it with
`WAYLAND_CLIENT_KIT_REQUEST_PROCESS_TIMEOUT_SECONDS`. The request runner invokes
the window-control and drag-source suites as separate test processes because
both use package-wide C request-recording hooks.

Graphics preview evidence is separate from ordinary Wayland smoke. Do not
promote graphics preview readiness unless
[compositor-matrix.md](compositor-matrix.md) contains graphics-preview rows for
headless Weston, one wlroots compositor such as Sway, and one desktop
compositor such as Mutter or KWin when available. Each row should include the
pasteable `WaylandClientKit GPU Preview Runtime Path` block from
`swift run wck smoke gpu-preview`, the `GraphicsPreviewManagedGPUClear` result when
available, exact missing optional interface names, and any advertised-but-broken
optional path failures.

`swift run wck tools toolchain-smoke` prints the active Swift wrapper version,
the `Package.swift` tools version, the Swift 6.3.2 stable baseline, optional
`SWIFT_NEXT_BIN` status, and the allowed-failure Swift Build preview status.
Native SwiftPM remains the supported build system, do not block a release on the
Swift Build preview unless the failure is a confirmed package regression.

Use repeated `swift test --filter ... --no-parallel` runs for local stress
validation of concurrency-sensitive suites. Repetition intentionally stays out
of the default release gate because useful counts are environment- and
time-dependent.

Under a real Wayland session:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run wck smoke gpu-preview
swift run GraphicsPreviewManagedGPUClear -- --auto-close --print-summary
swift run WaylandClientKitDemo
```

Compositor targets are Weston, GNOME/Mutter, KDE/KWin, and Sway/wlroots. A checkpoint
should not treat Weston-only behavior as sufficient for compositor compatibility.
Record results in [compositor-matrix.md](compositor-matrix.md).

## Tag Checklist

1. Confirm the working tree is clean.
2. Run `swift run wck tools toolchain-smoke` and confirm Swift 6.3.2 or newer is active.
3. Confirm dynamic glibc Linux bootstrap dependencies are installed or CI uses equivalent packages.
4. Run `swift run wck ci check`.
5. Run `swift run wck examples build` and the optimized release gate.
6. Run `swift run wck smoke live` under a Wayland session.
7. Run `swift run wck smoke integration` under a Wayland session.
8. Run `swift run wck smoke gpu-preview` under a Wayland session.
9. Manually run `swift run WaylandClientKitDemo` on at least one non-Weston desktop
   before treating compositor compatibility as proven.
10. Update `docs/compositor-matrix.md` with the compositor facts and check results.
11. Run `swift run wck compositor evidence-summary` and review missing evidence.
12. Regenerate protocols and confirm no diff.
13. Generate and review the public API report.
14. Run `swift run wck api verify`.
15. Run `swift run wck docc verify`.
16. Review `docs/public-api-audit.md`.
17. Update README support and unsupported lists if behavior changed.
18. Tag the checkpoint.
19. If publishing GitHub checkpoint notes, copy the supported and unsupported scope from README.

## Stop Conditions

Do not tag if any of these fail:

- generated-source verification,
- shim verification,
- strict concurrency build,
- tests,
- optimized build,
- public API report review,
- public API audit verification,
- live Wayland smoke test,
- or live Wayland public API integration test.

## Tag Text Template

Use factual scope text:

```markdown
WaylandClientKit is a development checkpoint for Linux Wayland client work.

Supported:
- Swift 6.3.2 package build.
- Dynamic glibc Linux bootstrap dependency checks through `pkg-config`.
- Core Wayland and stable xdg-shell generated artifacts.
- Project-owned C shims for supported requests and listeners.
- Display connection, registry discovery, and version-negotiated binds.
- Single-thread-affine event loop.
- Scale-aware wl_shm XRGB8888 software rendering.
- xdg-shell toplevel lifecycle.
- Frame callback paced redraw.
- Basic seat, pointer, keyboard, and touch input capture.
- Session-level public input draining.
- Basic xkb_v1 keyboard interpretation through xkbcommon.
- Compose and dead-key text results for interpreted keyboard events.
- Static pointer cursor surfaces through wayland-cursor.
- Public cursor animation over validated custom image frames.
- Cursor-shape requests where `wp_cursor_shape_manager_v1` is advertised.
- Server-side decoration negotiation through xdg-decoration.
- Popup surfaces with placement, redraw, dismissal, and target identity.
- Explicit presentation feedback through `wp_presentation`.
- Regular clipboard selection offers and sources through data-device.
- Primary selection offers and sources through primary-selection.
- Receive-side drag-and-drop offers through data-device.
- Source-side drag-and-drop sources through data-device.
- Managed XRGB8888 drag icon surfaces for local source-side drags.
- Seat-scoped text-input sessions and text-input event streams through text-input-v3.

Verification:
- swift run wck ci release
- swift run wck examples build
- swift run wayland-client-kit-smoke
- swift run wck smoke integration
- swift run wck smoke gpu-preview
- manual demo smoke test
```
