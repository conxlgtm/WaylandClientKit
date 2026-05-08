# Contributing

SwiftWayland is an experimental Linux Wayland client package. Keep changes small, protocol-shaped, and easy to verify.

## Environment

Swift 6.3.1 or newer must already be installed.
The bootstrap script verifies Swift and Linux system dependencies by default.
It does not install or switch Swift toolchains.
It uses `Scripts/swift.sh` by default.
Set `SWIFT_COMMAND=/path/to/swift` for custom toolchain resolution.

Core build requirements:

- Swift 6.3.1 or newer
- `clang`
- `pkg-config`
- `wayland-client`
- `wayland-cursor`
- `xkbcommon`

Install distro packages explicitly, or run the bootstrap installer mode for Debian/Ubuntu, Fedora/RHEL-like, Arch/Manjaro, openSUSE, Alpine, or Gentoo systems.
For Nix/NixOS, use dry-run mode to print shell inputs and add them to a `nix shell`, flake, or `shell.nix`.
Bootstrap install mode does not mutate Nix profiles or NixOS system configuration.

```bash
./Scripts/bootstrap-linux.sh --check
./Scripts/bootstrap-linux.sh --dry-run
./Scripts/bootstrap-linux.sh --dry-run --package-manager nix
./Scripts/bootstrap-linux.sh --install
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
./Scripts/integration-wayland.sh
swift run swift-wayland-demo
```

## Protocol Generation

Protocol XML lives under `Protocols/`. Generated C and header artifacts live under `Sources/CWaylandProtocols/`.

Regenerate only through:

```bash
./Scripts/bootstrap-linux.sh --maintainer
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

When a pull request adds, removes, or changes public `WaylandClient` declarations, update `docs/public-api-audit.md`.
If behavior appears in README support lists, update architecture and roadmap docs in the same change.

## Safety Review

Any new unsafe surface must explain the ownership invariant that makes it valid.
If the strict memory safety baseline or unsafe-token allowlist changes, describe why in the pull request.
Prefer scoped borrowed values, validated domain values, and package-internal C shims over raw pointer exposure.

## Scope Rule

Cut breadth before correctness.

Do not add GPU rendering, cursor animation, output management, primary selection, drag and drop, text input, IME, widgets, or multi-threaded queues as incidental side work.
Those belong in dedicated roadmap stories.
