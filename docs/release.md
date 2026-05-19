# Development Checkpoint Checklist

Tags are reproducible development checkpoints. They do not imply API stability.
Do not tag while docs, public API audit, support lists, and checks disagree.

## Required Checks

Run these from a clean working tree:

```bash
./scripts/dev/swift.sh --version
pkg-config --modversion egl
pkg-config --modversion gbm
pkg-config --modversion glesv2
pkg-config --modversion libdrm
pkg-config --modversion wayland-client
pkg-config --modversion xkbcommon
command -v wayland-scanner
make check
./scripts/dev/swift.sh build --disable-index-store -c release
./scripts/dev/swift.sh build --disable-index-store -c release --target SwiftWaylandDemo
./scripts/dev/swift.sh build --disable-index-store -c release --target GPUPreviewSmokeClient
./scripts/dev/swift.sh build --disable-index-store -c release --product swift-wayland-smoke
./scripts/ci/dump-public-api.sh > /tmp/swiftwayland-public-api.md
./scripts/ci/verify-public-api-audit.sh
./scripts/ci/verify-target-imports.sh
./scripts/ci/verify-docc.sh
bash ./scripts/safety/verify-unsafe-allowlist.sh
```

Prefer `make release-check` for the release build path. Direct `swift`
commands require equivalent runtime library configuration; the wrapper sources
`scripts/dev/swift-runtime-env.sh` before invoking Swift.

Where the environment supports Swift sanitizers, also run:

```bash
make test-tsan
make test-asan
```

ThreadSanitizer is the primary concurrency lifecycle check. AddressSanitizer
can be environment-dependent on Linux and may require host support for its
runtime and process instrumentation.

Under a real Wayland session:

```bash
./scripts/smoke/collect-compositor-facts.sh
./scripts/smoke/smoke-wayland.sh
./scripts/smoke/integration-wayland.sh
make gpu-preview-wayland
./scripts/dev/swift.sh run SwiftWaylandDemo
```

Compositor targets are Weston, GNOME/Mutter, KDE/KWin, and Sway/wlroots. A checkpoint
should not treat Weston-only behavior as sufficient for compositor compatibility.
Record results in [compositor-matrix.md](compositor-matrix.md).

## Tag Checklist

1. Confirm the working tree is clean.
2. Confirm Swift 6.3.2 is active.
3. Confirm dynamic glibc Linux bootstrap dependencies are installed or CI uses equivalent packages.
4. Run `make check`.
5. Run optimized builds for the package, demo, GPU preview smoke client, and smoke executable.
6. Run `./scripts/smoke/smoke-wayland.sh` under a Wayland session.
7. Run `./scripts/smoke/integration-wayland.sh` under a Wayland session.
8. Run `make gpu-preview-wayland` under a Wayland session.
9. Manually run `./scripts/dev/swift.sh run SwiftWaylandDemo` on at least one non-Weston desktop
   before treating compositor compatibility as proven.
10. Update `docs/compositor-matrix.md` with the compositor facts and check results.
11. Regenerate protocols and confirm no diff.
12. Generate and review the public API report.
13. Run `./scripts/ci/verify-public-api-audit.sh`.
14. Run `./scripts/ci/verify-docc.sh`.
15. Review `docs/public-api-audit.md`.
16. Update README support and unsupported lists if behavior changed.
17. Tag the checkpoint.
18. If publishing GitHub checkpoint notes, copy the supported and unsupported scope from README.

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
SwiftWayland is a development checkpoint for Linux Wayland client work.

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

Not supported:
- Widgets.
- Public cursor animation or per-output cursor policy APIs.
- Client-side decorations.
- Full output-management API.
- Public `WaylandClient` GPU rendering APIs.
- Multi-threaded event queues.
- Server-side Wayland or compositor APIs.

Verification:
- make check
- ./scripts/dev/swift.sh build --disable-index-store -c release
- ./scripts/dev/swift.sh run swift-wayland-smoke
- ./scripts/smoke/integration-wayland.sh
- make gpu-preview-wayland
- manual demo smoke test
```
