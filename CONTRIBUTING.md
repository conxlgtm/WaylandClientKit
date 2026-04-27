# Contributing

SwiftWayland is an experimental Linux Wayland client package. Keep changes small, protocol-shaped, and easy to verify.

## Environment

Reference environment:

- Fedora
- Swift 6.3.1
- `wayland-devel`
- `wayland-protocols-devel`
- `pkgconf-pkg-config`
- `libxkbcommon-devel`
- `git`
- `ripgrep`
- `clang`

Swift itself must already be installed and on `PATH` before running the bootstrap script.

```bash
./Scripts/bootstrap-fedora.sh
```

## Local Checks

Before opening a pull request, run:

```bash
make check
swift build -c release
```

Under a real Wayland session, also run:

```bash
./Scripts/smoke-wayland.sh
swift run swift-wayland-demo
```

## Protocol Generation

Protocol XML lives under `Protocols/`. Generated C and header artifacts live under `Sources/CWaylandProtocols/`.

Regenerate only through:

```bash
./Scripts/generate-protocols.sh
```

Verify generated outputs with:

```bash
./Scripts/verify-generated.sh
```

Do not edit generated files directly.

## Adding A Protocol

Protocol additions must update these together:

- vendored XML,
- generated artifacts,
- C shim declarations and implementations,
- raw Swift wrappers,
- public overlay docs when the protocol is surfaced publicly,
- tests,
- and generated/shim verification scripts.

If a protocol cannot be covered end to end in one change, keep it out of the experimental baseline and add it to `docs/roadmap.md`.

## C Shims

Swift should call project-owned C shims, not generated inline protocol helpers directly. When adding or removing a Swift-facing shim, update:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/`
- `Scripts/verify-shims.sh`
- listener smoke tests where applicable.

## Public API

Use the narrowest access level that works.

Preferred order:

```text
private
internal
package
public
```

`WaylandClient` is the primary public overlay. `WaylandRaw` is intentionally protocol-shaped and less stable. Keep raw details out of `WaylandClient` unless they are part of the documented experimental API.

## Scope Rule

Cut breadth before correctness.

Do not add GPU rendering, cursor themes, decorations, clipboard, drag and drop, text input, IME, widgets, or multi-threaded queues as incidental side work. Those belong in dedicated roadmap stories.
