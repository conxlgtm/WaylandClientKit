# Release Checklist

Tags are reproducible development checkpoints. They do not imply API stability.

## Checkpoint Version

Use:

```text
0.0.1
```

Do not imply API stability in tag text or GitHub release text.

## Required Checks

Run these from a clean working tree:

```bash
swift --version
pkg-config --modversion wayland-client
pkg-config --modversion xkbcommon
command -v wayland-scanner
make check
swift build -c release
swift build -c release --product swift-wayland-demo
swift build -c release --product swift-wayland-smoke
./Scripts/dump-public-api.sh > /tmp/swiftwayland-public-api.md
```

Under a real Wayland session:

```bash
./Scripts/smoke-wayland.sh
swift run swift-wayland-demo
```

Release targets are Weston, GNOME/Mutter, KDE/KWin, and Sway/wlroots. A checkpoint
should not treat Weston-only behavior as sufficient for compositor compatibility.

## Tag Checklist

1. Confirm the working tree is clean.
2. Confirm Swift 6.3.1 is active.
3. Confirm Linux bootstrap dependencies are installed or CI uses equivalent packages.
4. Run `make check`.
5. Run release builds for the package, demo, and smoke executable.
6. Run `./Scripts/smoke-wayland.sh` under a Wayland session.
7. Manually run `swift run swift-wayland-demo` on at least one non-Weston desktop
   before treating compositor compatibility as release-ready.
8. Regenerate protocols and confirm no diff.
9. Generate and review the public API report.
10. Review `docs/public-api-audit.md`.
11. Update README support and unsupported lists if behavior changed.
12. Tag the checkpoint.
13. If publishing a GitHub release, copy the supported and unsupported scope from README.

## Stop Conditions

Do not tag if any of these fail:

- generated-source verification,
- shim verification,
- strict concurrency build,
- tests,
- release build,
- public API report review,
- or live Wayland smoke test.

## Tag Text

Use factual scope text:

```markdown
SwiftWayland 0.0.1 is a development checkpoint for Linux Wayland client work.

Supported:
- Swift 6.3.1 package build.
- Linux bootstrap dependency checks.
- Core Wayland and stable xdg-shell generated artifacts.
- Project-owned C shims for supported requests and listeners.
- Display connection, registry discovery, and version-negotiated binds.
- Single-thread-affine event loop.
- wl_shm XRGB8888 software rendering.
- xdg-shell toplevel lifecycle.
- Frame callback paced redraw.
- Basic seat, pointer, keyboard, and touch input capture.
- Session-level public input draining.
- Basic xkb_v1 keyboard interpretation through xkbcommon.
- Static pointer cursor surfaces through wayland-cursor.

Not supported:
- Widgets.
- Text input, compose handling, or IME.
- Clipboard, primary selection, or drag and drop.
- Cursor animation or per-output cursor scaling.
- Decorations.
- Fractional scaling.
- Presentation timing.
- EGL, GBM, dmabuf, or GPU rendering.
- Multi-threaded event queues.
- Server-side Wayland or compositor APIs.

Verification:
- make check
- swift build -c release
- swift run swift-wayland-smoke
- manual demo smoke test
```
