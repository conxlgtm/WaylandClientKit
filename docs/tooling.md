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

## Swift Toolchain And Build Artifacts

Swift 6.4.0 is the minimum compiler; Swift 6 language mode and the existing
strict concurrency and memory-safety settings remain enabled. SwiftPM's default
Swift Build backend is required, not an allowed-failure preview.

On Nix, set an optional `SWIFT_BIN` before entering `nix develop`. The shell
generates a platform- and compiler-specific SDK/toolset, wraps the selected
compiler tools, and supplies SDK selection to ordinary SwiftPM commands.
It does not install a global SDK or export runtime library overrides to Git.
SwiftLint uses the selected SourceKit library and a tool-scoped loader on Nix,
including its custom-rule probe. Script-based overrides run through their own
interpreter.

Swift Build uses per-target `*-test-runner` executables, dynamic test bundles,
and a products/intermediates layout. Maintainer checks discover artifacts from
the selected scratch tree rather than assuming the old monolithic test bundle
or native-backend object paths. ThreadSanitizer retains nonparallel execution
and the host's fixed-address-layout requirements.
Filtered sanitizer runs discover tests in each runner and execute only matching
targets. A filter matching no target fails; unrelated targets do not turn
Swift Testing's no-matching-tests exit status into a sanitizer failure.
Public integration packages also run nonparallel: live suites share compositor
layout and configure state, even when individual test suites are serialized.

Enable unit coverage with `WAYLAND_CLIENT_KIT_UNIT_COVERAGE=1` or request-path
coverage with `WAYLAND_CLIENT_KIT_HEADLESS_COVERAGE=1`, then run
`swift run wck coverage summarize`. SwiftPM replaces its managed coverage
directory between invocations and reuses the package JSON name between targets.
The test commands merge each invocation's raw profiles into
`wck-coverage.profdata` beside the selected build products before another filter
runs. The summary exports all target bundles together through LLVM, without
counting shared source files repeatedly. Separate unit and request-path runs
start with a fresh accumulated profile. Profile merging and multi-object export
use `llvm-profdata` and `llvm-cov` beside the selected Swift compiler, not
unrelated tools on `PATH`.

The public API baseline supplements symbol graphs with compiler-parsed ownership
records, distinguishing `borrow` and `mutate` accessors from `borrowing get` and
`consuming get`, including public properties in copyable value types.

Documentation coverage counts product-authored public symbol abstracts.
Documentation inherited from dependency modules does not count toward
`docs/documentation-symbol-coverage.json`, so standard-library documentation
loading cannot change the product's coverage gate.

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
| `swift run wck ci required` | Public API and documentation baselines, strict build, unit tests, integration packages, the expected-failure graphics policy client, and invalid graphics-lease clients for duplicate consumption and post-transfer reuse. |
| `swift run wck ci check` | Cheap and required gates plus Markdown and DocC verification. |
| `swift run wck ci release` | Check gate plus release builds, release tests, freshness checks, sanitizers where configured, and an available live or headless Wayland path. |

Pull requests require the `check / required` status. Scheduled and manual full
workflows run the additional release, sanitizer, generated-freshness, and
headless jobs.
