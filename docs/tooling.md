# Tooling Ownership

`wck` is the canonical maintainer CLI. Checks that define project truth should
live in `WaylandClientKitToolSupport`, be exposed through `swift run wck ...`, and
then be wrapped only where that improves ergonomics.

## Roles

### `wck`

`swift run wck ...` owns maintainer workflows: bootstrap checks, formatting,
linting, protocol generation and verification, DocC verification, public API
verification, identity visibility verification, shim checks, unsafe-token checks,
example builds, smoke tests,
coverage summaries, compositor evidence summaries, and CI/release gates.

### SwiftPM Plugins

SwiftPM command plugins are convenience wrappers around `wck`:

- `swift package wck-check` runs `swift run wck ci check`
- `swift package wck-release-check` runs `swift run wck ci release`
- `swift package wck-generate-protocols` runs `swift run wck protocols generate`
- `swift package wck-verify-generated` runs `swift run wck protocols verify-generated`
- `swift package wck-bootstrap-check` runs `swift run wck bootstrap check`

Plugins set SwiftPM scratch paths for plugin isolation, but they do not define
separate check behavior.

### `scripts/`

The repository does not keep project-owned shell orchestration under `scripts/`.
If a script directory is reintroduced, every file in it must be a compatibility,
low-level, or external-tool wrapper whose behavior is owned by `wck` or by a
documented upstream tool.

### `justfile`

`justfile` contains contributor convenience aliases only. It should call `wck`
or `nix develop -c swift run wck ...` and should not become a second source of
truth.

### `flake.nix`

`flake.nix` owns the development environment. It is not release truth. Release
and CI behavior still flow through `wck`.

### GitHub Actions

GitHub Actions orchestrate the CI environment around `wck`. CI should run the
same `swift run wck ...` commands that contributors are told to run locally.

## Rule For New Checks

New checks should be implemented in `WaylandClientKitToolSupport` first, exposed
through `wck`, and then optionally wrapped by SwiftPM plugins, `just`, Nix, or
external automation.

## External Dependency Policy

Runtime and library products should avoid external SwiftPM dependencies unless
they are deliberately approved for the public product graph.

Tooling targets may use external dependencies when they materially improve
maintainability. `swift-argument-parser` is allowed for `WaylandClientKitTool`
because it owns the maintainer CLI, not the runtime libraries.

`Package.resolved` is committed intentionally. Dependency updates require the
normal branch or release validation for their risk level.

Public library products must not accidentally depend on tool-only packages.
`swift run wck ci cheap` verifies that the `WaylandClient` and
`WaylandGraphicsPreview` dependency graphs do not include `ArgumentParser` or
tool-only targets.

## CI Gates

`swift run wck ci cheap` runs formatting, lint, generated-file, manifest, shim,
dependency-boundary, import-boundary, public identity visibility, and unsafe-token checks. It is a fast
signal and does not prove that the library products compile.

`swift run wck ci required` verifies the compiler-derived public API baseline,
performs the strict-concurrency build, runs unit tests, and builds and tests all
four external integration packages. It also builds an expected-failure graphics
client and verifies that the removed split presentation/fallback initializer is
rejected, so contradictory graphics configurations cannot return unnoticed.
Pull requests must pass the `check / required` status before merge.

`swift run wck ci check` adds documentation and DocC verification to the cheap
and required gates. Scheduled and manually dispatched full workflows also run
release, sanitizer, generated-freshness, and headless Wayland jobs.
