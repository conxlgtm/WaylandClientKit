# Contributing

WaylandClientKit is an experimental Linux Wayland client package. Keep changes small, protocol-shaped, and easy to verify.

## Environment

Swift 6.3.2 or newer must already be installed.
`swift run wck bootstrap check` verifies Swift and Linux system dependencies.
It does not install or switch Swift toolchains.
Set `SWIFT_BIN=/path/to/swift` for custom toolchain resolution.

CI currently validates dynamic glibc Linux on Ubuntu Noble with shared
Wayland, XKB, and cursor libraries resolved through `pkg-config`. Package-manager
rows are dependency hints for contributors. Musl, static Linux SDK builds, and
static linking need dedicated CI before they are treated as supported.

On openSUSE, Swift 6.3.2 SwiftPM may need a compatibility `libxml2.so.2`.
Project Swift wrappers load `$SWIFT_COMPAT_LIBS` when present, defaulting to
`$HOME/.local/share/swift-compat-libs`.

Core build requirements:

- Swift 6.3.2 or newer
- `clang`
- `pkg-config`
- `gbm`
- `libdrm`
- `wayland-client`
- `wayland-cursor`
- `xkbcommon`

Install distro packages explicitly, or print the package-manager command for Debian/Ubuntu, Fedora/RHEL-like, Arch/Manjaro, openSUSE, Alpine, or Gentoo systems.
For Nix/NixOS, use `nix develop`.
Bootstrap commands print installation guidance only; they do not mutate the machine.

```bash
swift run wck bootstrap check
swift run wck bootstrap install-command --package-manager dnf
swift run wck bootstrap install-command --package-manager nix
```

## Local Checks

Before opening a pull request, run:

```bash
swift run wck tools toolchain-smoke
swift run wck ci check
```

Under a real Wayland session, also run:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run WaylandClientKitDemo
```

For a private headless Weston compositor, run:

```bash
swift run wck smoke headless -- wck smoke integration
```

SwiftPM command plugins wrap the same checks:

```bash
swift package wck-check
swift package wck-release-check
swift package wck-generate-protocols
swift package wck-verify-generated
swift package wck-bootstrap-check
```

See [Linux live Wayland testing](docs/live-wayland-testing.md) for the live
test contract, package commands, and optional protocol skip policy.
See [Tooling Ownership](docs/tooling.md) for the command ownership model,
dependency policy, and wrapper rules.

## Protocol Generation

Protocol XML lives under `protocols/`. Generated C and header artifacts live under `Sources/CWaylandProtocols/`.

Regenerate only through:

```bash
swift run wck bootstrap maintainer-check
swift run wck protocols generate
```

Verify generated outputs with:

```bash
swift run wck protocols verify-generated
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
- and generated/shim verification checks.

If a protocol cannot be covered end to end in one change, keep it out of the experimental baseline and add it to `docs/roadmap.md`.

## C Shims

Swift should call project-owned C shims, not generated inline protocol helpers directly. When adding or removing a Swift-facing shim, update:

- `Sources/CWaylandProtocols/include/wayland-client-kit-shims.h`
- `Sources/CWaylandProtocols/shims/`
- `swift run wck shims verify`
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
If the unsafe-token allowlist changes, describe why in the pull request.
Prefer scoped borrowed values, validated domain values, and package-internal C shims over raw pointer exposure.

## Dependency Policy

Runtime and library products should avoid external SwiftPM dependencies unless
they are deliberately approved for the public product graph. Tooling targets may
use external dependencies when they materially improve maintainability.
`Package.resolved` is committed intentionally, and dependency updates require
the relevant `swift run wck ci ...` validation. `swift run wck ci cheap` checks
that tool-only dependencies do not leak into `WaylandClient` or
`WaylandGraphicsPreview`.

## Scope Rule

Cut breadth before correctness.

Do not expand GPU rendering, cursor animation, output management, data transfer,
text input, IME/input-method behavior, widgets, or multi-threaded queues as
incidental side work. Those belong in dedicated roadmap stories.
