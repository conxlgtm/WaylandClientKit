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

Swift 6.4.0 is required. Packages use Swift 6 language mode with the existing
strict concurrency and memory-safety settings. The default Swift Build backend
is required.

On Nix, set `SWIFT_BIN` before running `nix develop` to choose a compiler.
The shell builds an SDK/toolset for that compiler and Nix platform, wraps the
compiler tools, and passes SDK selection to SwiftPM without a global SDK
installation. Runtime library overrides do not reach Git. SwiftLint uses the
selected SourceKit library and a tool-scoped loader, including during custom-rule
checks. Script overrides use their own interpreters.

Swift Build emits per-target `*-test-runner` executables, dynamic test bundles,
and separate products and intermediates directories. Checks read artifacts from
the selected scratch tree, replacing assumptions about monolithic test bundles
and native-backend object paths. ThreadSanitizer runs tests without parallelism
and still requires the host's fixed address layout.

Filtered sanitizer runs list each runner's tests and execute matching targets.
A filter that matches no target fails. Unrelated targets are skipped, so Swift
Testing's no-matching-tests exit status does not fail the sanitizer run.
Public integration packages also run without parallelism because live suites
share compositor layout and configure state, even when suites are serialized.

Enable unit coverage with `WAYLAND_CLIENT_KIT_UNIT_COVERAGE=1` or request-path
coverage with `WAYLAND_CLIENT_KIT_HEADLESS_COVERAGE=1`, then run
`swift run wck coverage summarize`. SwiftPM replaces its managed coverage
directory between invocations and reuses the package JSON name for each target.
Before the next filter runs, the test commands merge raw profiles into
`wck-coverage.profdata` beside the build products. The summary exports all target
bundles together through LLVM, counting shared source files once. Unit and
request-path runs each start with a fresh accumulated profile. Profile merging
and multi-object export use `llvm-profdata` and `llvm-cov` beside the selected
Swift compiler, keeping coverage tools on the same toolchain as the build.

Sanitizer builds replace the instrumented test bundles. Collect coverage again
before summarizing if the build flags changed after the coverage run.

The public API baseline adds compiler-parsed ownership records to symbol graphs.
It distinguishes `borrow` and `mutate` accessors from `borrowing get` and
`consuming get`, including public properties in copyable value types.
Types declared inside functions, initializers, accessors, and closures are
excluded from the module-wide visibility index, so a function-local name cannot
hide a public ownership record.

Documentation coverage counts product-authored public symbol abstracts in
`docs/documentation-symbol-coverage.json`. Inherited dependency comments are
excluded, so loading standard-library documentation does not change the gate.

## Tool Processes

`wck` uses the async `Subprocess` 1.0.0 backend for child processes. It replaces
the manual spawn/wait code and pipe readers. There is no synchronous bridge or
fallback runner.

Executable lookup uses the runner's stored `PATH`; per-command overrides affect
the child environment, not lookup. Children receive that exact environment,
the requested working directory, and inherited stdin. Malformed environment
names or NUL-containing values fail before launch and become `ToolError`s.

Ordinary commands capture stdout and stderr in separate temporary files without
output limits. Decoding is strict UTF-8: an invalid stream becomes an empty
string. Linux signal exits use `128 + signal`; headless commands retain the raw
signal status.

Headless Weston runs use merged, file-backed logs and the configured child
deadline. Teardown gives each process five seconds after SIGTERM before a final
kill. The child settles before Weston stops; both settle before logs close or
the private runtime directory is removed. Targeting remains direct-PID only.

SwiftPM command plugins keep their isolated Foundation launchers. Those outer
plugin-host adapters launch `wck`; they do not implement another tool backend.

## Dependencies

Public library products require review before acquiring an external SwiftPM
dependency. `swift-argument-parser` is limited to the maintainer CLI.
`swift-subprocess` 1.0.0 and its `swift-system` dependency are tool-only.

`Package.resolved` records exact revisions. `swift run wck ci cheap` checks that
the public product graphs exclude `ArgumentParser`, `Subprocess`, `SystemPackage`,
their packages, and tool-only targets.

## Gates

| Gate | Checks |
| --- | --- |
| `swift run wck ci cheap` | Format, lint, generated files, manifests, shims, dependency and import boundaries, identity declarations, and unsafe tokens. |
| `swift run wck ci required` | Public API and documentation baselines, strict build, unit tests, integration packages, the expected-failure graphics policy client, and invalid graphics-lease clients for duplicate consumption, post-transfer reuse, and borrows kept across consuming operations. |
| `swift run wck ci check` | Cheap and required gates plus Markdown and DocC verification. |
| `swift run wck ci release` | Check gate plus release builds, release tests, freshness checks, sanitizers where configured, and an available live or headless Wayland path. |

Pull requests require the `check / required` status. Scheduled and manual full
workflows run the additional release, sanitizer, generated-freshness, and
headless jobs.
