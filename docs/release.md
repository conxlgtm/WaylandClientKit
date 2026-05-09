# Development Checkpoint Checklist

Tags are reproducible development checkpoints. They do not imply API stability.
Do not tag while docs, public API audit, support lists, and checks disagree.

## Required Checks

Run these from a clean working tree:

```bash
swift --version
pkg-config --modversion wayland-client
pkg-config --modversion xkbcommon
command -v wayland-scanner
make check
swift build -c release
swift build -c release --target SwiftWaylandDemo
swift build -c release --product swift-wayland-smoke
./scripts/ci/dump-public-api.sh > /tmp/swiftwayland-public-api.md
```

Under a real Wayland session:

```bash
./scripts/smoke/smoke-wayland.sh
./scripts/smoke/integration-wayland.sh
swift run SwiftWaylandDemo
```

Compositor targets are Weston, GNOME/Mutter, KDE/KWin, and Sway/wlroots. A checkpoint
should not treat Weston-only behavior as sufficient for compositor compatibility.

## Tag Checklist

1. Confirm the working tree is clean.
2. Confirm Swift 6.3.1 is active.
3. Confirm dynamic glibc Linux bootstrap dependencies are installed or CI uses equivalent packages.
4. Run `make check`.
5. Run optimized builds for the package, demo, and smoke executable.
6. Run `./scripts/smoke/smoke-wayland.sh` under a Wayland session.
7. Run `./scripts/smoke/integration-wayland.sh` under a Wayland session.
8. Manually run `swift run SwiftWaylandDemo` on at least one non-Weston desktop
   before treating compositor compatibility as proven.
9. Regenerate protocols and confirm no diff.
10. Generate and review the public API report.
11. Review `docs/public-api-audit.md`.
12. Update README support and unsupported lists if behavior changed.
13. Tag the checkpoint.
14. If publishing GitHub checkpoint notes, copy the supported and unsupported scope from README.

## Stop Conditions

Do not tag if any of these fail:

- generated-source verification,
- shim verification,
- strict concurrency build,
- tests,
- optimized build,
- public API report review,
- live Wayland smoke test,
- or live Wayland public API integration test.

## Tag Text Template

Use factual scope text:

```markdown
SwiftWayland is a development checkpoint for Linux Wayland client work.

Supported:
- Swift 6.3.1 package build.
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
- Server-side decoration negotiation through xdg-decoration.
- Popup surfaces with placement, redraw, dismissal, and target identity.
- Regular clipboard selection offers and sources through data-device.
- Primary selection offers and sources through primary-selection.

Not supported:
- Widgets.
- Text input or IME.
- Drag and drop.
- Cursor animation or per-output cursor scaling.
- Client-side decorations.
- Full output-management API.
- Presentation timing.
- EGL, GBM, dmabuf, or GPU rendering.
- Multi-threaded event queues.
- Server-side Wayland or compositor APIs.

Verification:
- make check
- swift build -c release
- swift run swift-wayland-smoke
- ./scripts/smoke/integration-wayland.sh
- manual demo smoke test
```
