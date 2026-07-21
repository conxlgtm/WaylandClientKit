# Contributing

WaylandClientKit is an experimental Linux Wayland client package. Keep changes
small and protocol-shaped.

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Use [Support](SUPPORT.md) for
questions and issue routing. Report vulnerabilities according to
[Security](SECURITY.md), not through public issues.

## Environment

Swift 6.3.2 or newer is required. Install the packages listed in
[Linux Dependencies](docs/linux-dependencies.md), or use `nix develop` on NixOS.

```bash
swift run wck tools toolchain-smoke
swift run wck bootstrap check
```

These commands report missing tools and libraries. They do not install packages
or switch Swift toolchains. Set `SWIFT_BIN=/path/to/swift` to select a toolchain.

CI tests dynamic glibc Linux with shared libraries resolved through
`pkg-config`. Musl, static Linux SDK builds, and static linking are not supported.

## Local Checks

Before opening a pull request, run:

```bash
swift run wck tools install-swiftlint --destination .build/tools
swift run wck tools toolchain-smoke
swift run wck ci check
```

Under a Wayland session, also run the relevant live checks and examples:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run --package-path Examples WaylandClientKitDemo
```

For a private Weston compositor:

```bash
swift run wck smoke headless -- wck smoke integration
```

See [Linux Live Wayland Testing](docs/live-wayland-testing.md) for environment
variables, optional-protocol skips, and compositor evidence.

## Protocol Changes

Protocol XML lives under `protocols/`. Generated C and header files live under
`Sources/CWaylandProtocols/`. Generated files are updated through the commands
below rather than by direct edits.

```bash
swift run wck bootstrap maintainer-check
swift run wck protocols generate
swift run wck protocols verify-generated
swift run wck shims verify
```

A complete protocol addition includes its vendored XML, generated files, C
shims, raw Swift wrappers, public docs when applicable, and tests. Protocols can
wait until those pieces are ready to ship together.

See [Protocol Generation](docs/generation.md) for manifests, policies, and output
paths.

## Public API

Use the narrowest access level that works: `private`, `internal`, `package`, then
`public`.

`WaylandClient` is the main public product. Keep raw protocol details out of it.
When a public declaration changes, update the public API baseline, public API
audit, DocC, tests, and user-facing docs required by the
[Compatibility Policy](docs/compatibility-policy.md).

`WaylandGraphicsPreview` may expose only the narrow, move-only interop values
allowed by that policy. Raw Wayland, GBM, EGL, and DRM objects remain internal.

## Safety

New unsafe code needs documentation for:

- the owner of the underlying object
- the permitted thread or executor
- transfer and invalidation rules
- deinitialization behavior

Update the strict memory-safety audit when unsafe-token or unchecked
`Sendable` use changes. Prefer scoped borrows, validated domain values, and
package-internal C shims over raw pointer exposure.

## Dependencies

External SwiftPM dependencies in public library products require a documented
review of the public product graph. Tool targets may use external packages when
the pull request names the maintenance benefit.

Commit `Package.resolved` changes and run the validation appropriate to the
dependency. `swift run wck ci cheap` checks that tool-only dependencies do not
enter `WaylandClient` or `WaylandGraphicsPreview`.

## Scope

GPU rendering, cursor animation, output management, data transfer, text input,
widgets, and multithreaded queues work best as separate changes with their own
tests and documentation.
