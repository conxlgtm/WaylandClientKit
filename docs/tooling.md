# Tooling Ownership

`swl` is the canonical maintainer CLI. Checks that define project truth should
live in `SwiftWaylandToolSupport`, be exposed through `swift run swl ...`, and
then be wrapped only where that improves ergonomics.

## Roles

### `swl`

`swift run swl ...` owns maintainer workflows: bootstrap checks, formatting,
linting, protocol generation and verification, DocC verification, public API
verification, shim checks, unsafe-token checks, example builds, smoke tests,
coverage summaries, compositor evidence summaries, and CI/release gates.

### SwiftPM Plugins

SwiftPM command plugins are convenience wrappers around `swl`:

- `swift package swl-check` runs `swift run swl ci check`
- `swift package swl-release-check` runs `swift run swl ci release`
- `swift package swl-generate-protocols` runs `swift run swl protocols generate`
- `swift package swl-verify-generated` runs `swift run swl protocols verify-generated`
- `swift package swl-bootstrap-check` runs `swift run swl bootstrap check`

Plugins set SwiftPM scratch paths for plugin isolation, but they do not define
separate check behavior.

### `scripts/`

The repository does not keep project-owned shell orchestration under `scripts/`.
If a script directory is reintroduced, every file in it must be a compatibility,
low-level, or external-tool wrapper whose behavior is owned by `swl` or by a
documented upstream tool.

### `justfile`

`justfile` contains contributor convenience aliases only. It should call `swl`
or `nix develop -c swift run swl ...` and should not become a second source of
truth.

### `flake.nix`

`flake.nix` owns the development environment. It is not release truth. Release
and CI behavior still flow through `swl`.

### GitHub Actions

GitHub Actions orchestrate the CI environment around `swl`. CI should run the
same `swift run swl ...` commands that contributors are told to run locally.

## Rule For New Checks

New checks should be implemented in `SwiftWaylandToolSupport` first, exposed
through `swl`, and then optionally wrapped by SwiftPM plugins, `just`, Nix, or
external automation.

## External Dependency Policy

Runtime and library products should avoid external SwiftPM dependencies unless
they are deliberately approved for the public product graph.

Tooling targets may use external dependencies when they materially improve
maintainability. `swift-argument-parser` is allowed for `SwiftWaylandTool`
because it owns the maintainer CLI, not the runtime libraries.

`Package.resolved` is committed intentionally. Dependency updates require the
normal branch or release validation for their risk level.

Public library products must not accidentally depend on tool-only packages.
`swift run swl ci cheap` verifies that the `WaylandClient` and
`WaylandGraphicsPreview` dependency graphs do not include `ArgumentParser` or
tool-only targets.
