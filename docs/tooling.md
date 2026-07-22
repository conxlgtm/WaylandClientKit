# Tooling

`wck` defines the repository's maintainer workflows. Other entry points call the
same commands.

## Command Ownership

| Entry point | Role |
| --- | --- |
| `swift run wck ...` | Implements bootstrap, format, lint, generation, API, DocC, identity, shim, safety, example, smoke, coverage, evidence, and CI commands. |
| SwiftPM command plugins | Provide package-level aliases for selected `wck` commands. |
| `justfile` | Provides short contributor aliases. |
| `flake.nix` | Supplies the development toolchain and system libraries. |
| GitHub Actions | Creates CI environments and invokes `wck` gates. |

New checks belong in `WaylandClientKitToolSupport` with a `wck` command. A
SwiftPM plugin, `just` recipe, Nix command, or CI job may then expose that
command without defining separate behavior.

The current SwiftPM aliases are:

| Alias | Command |
| --- | --- |
| `swift package wck-check` | `swift run wck ci check` |
| `swift package wck-release-check` | `swift run wck ci release` |
| `swift package wck-generate-protocols` | `swift run wck protocols generate` |
| `swift package wck-verify-generated` | `swift run wck protocols verify-generated` |
| `swift package wck-bootstrap-check` | `swift run wck bootstrap check` |

## Dependencies

Public library products require review before acquiring an external SwiftPM
dependency. Tool targets may use one when the change documents the maintenance
benefit. `swift-argument-parser` is limited to the maintainer CLI.

`Package.resolved` is committed. `swift run wck ci cheap` checks that
`WaylandClient` and `WaylandGraphicsPreview` do not depend on `ArgumentParser` or
tool-only targets.

## Gates

| Gate | Checks |
| --- | --- |
| `swift run wck ci cheap` | Format, lint, generated files, manifests, shims, dependency and import boundaries, identity declarations, and unsafe tokens. |
| `swift run wck ci required` | Public API and documentation baselines, strict build, unit tests, integration packages, and the expected-failure graphics policy client. |
| `swift run wck ci check` | Cheap and required gates plus Markdown and DocC verification. |
| `swift run wck ci release` | Check gate plus release builds, release tests, freshness checks, sanitizers where configured, and an available live or headless Wayland path. |

Pull requests require the `check / required` status. Scheduled and manual full
workflows run the additional release, sanitizer, generated-freshness, and
headless jobs.
