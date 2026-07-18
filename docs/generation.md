# Protocol Generation

## Inputs

Vendored XML files:

- `protocols/upstream/core/`
- `protocols/upstream/stable/`
- `protocols/upstream/staging/`
- `protocols/upstream/legacy-unstable/`
- `protocols/manifest.json`

These files are committed. `protocols/manifest.json` is the source of truth for
the protocol inventory, source-resolution strategy, override environment
variable, pkg-config package and variable, source candidates, generated header
and C output paths, scanner modes, checksum, tier, exposure, and test strategy.
Run `swift run wck protocols list` to print the tracked inventory.

Do not edit generated files directly. Change the vendored XML or protocol manifest metadata, regenerate, and review the generated diff.
Tool ownership is described in [Tooling Ownership](tooling.md). New protocol
checks should be implemented in `WaylandClientKitToolSupport` and exposed through
`wck`.

## Schema IR And Client Policy

`WaylandProtocolXMLParser` reads each vendored XML file into a small intermediate
representation before generation starts. The model keeps interfaces, versions,
requests, events, arguments, opcodes, destructors, and enumerations in source
order. Parsing every input first also means malformed XML cannot leave the
checked-in generated directories half replaced.

The XML model contains protocol facts only. Client choices such as the highest
version WaylandClientKit implements, a minimum bindable version, and whether a
global is required or optional belong in `WaylandProtocolGenerationPolicy`.
That policy is a JSON overlay so these choices do not get mixed into vendored
upstream XML.

The current generator still uses `wayland-scanner` for its checked-in C output,
and the C shims remain handwritten. It also generates `SupportedVersions.swift`
from the parsed interface versions and `protocols/generation-policy.json`. The
policy records the client version cap, any non-default minimum version, and
whether each supported global is required or optional. For optional globals, it
also records whether the public capability inventory reports the interface. An
optional global retained for the display lifetime records its wrapper type,
stored property, binding method, and acquisition order. The generator uses that
metadata for optional-global storage, binding rollback, invalidation, and
reverse-order destruction. The raw bind methods and their unsafe C calls remain
handwritten.

## Generated Outputs

Generated headers:

- `Sources/CWaylandProtocols/include/generated/`

Generated C files:

- `Sources/CWaylandProtocols/generated/`

Generated Swift files:

- `Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift`
- `Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift`

These files are committed. The exact file set comes from `generatedHeaderPath`
and `generatedCodePath` in `protocols/manifest.json`, plus the supported globals
listed in `protocols/generation-policy.json`.

## Shim Files

These files are not generated:

- `Sources/CWaylandProtocols/include/wayland-client-kit-shims.h`
- `Sources/CWaylandProtocols/shims/*.c`

## Tools

- `wayland-scanner`
- `ripgrep`
- `pkg-config`

## Commands

Sync XML from the local system:

```bash
swift run wck bootstrap maintainer-check
swift run wck protocols sync
```

Generate protocol artifacts from vendored XML:

```bash
swift run wck protocols generate
```

Verify that vendored XML and generated outputs are in sync:

```bash
swift run wck protocols verify-generated
```

Verify that every manifest entry records tier, exposure, and test policy:

```bash
swift run wck protocols verify-manifest
```

Run the full local gate:

```bash
swift run wck ci check
```

Verify the hand-written C shim declarations and implementations cover the
currently-supported Swift surface:

```bash
swift run wck shims verify
```

Verify DocC symbol references:

```bash
swift run wck docc verify-symbol-links
```

## Command Responsibilities

### `swift run wck protocols sync`

Copies protocol XML from the local system.

Default source resolution matches `protocols/manifest.json`. The command checks
the manifest override environment variable, pkg-config package data directory
plus relative candidates, absolute fallback candidates, and finally the
checked-in vendored XML. The selected source must match the manifest checksum
before it is copied.

Run `swift run wck protocols sources` to print the selected source for every
manifest entry without copying files.

Run `swift run wck bootstrap maintainer-check` first to verify the scanner,
`wayland-protocols` pkg-config module, and protocol XML inputs.

### `swift run wck protocols generate`

Reads:

- `protocols/`
- `protocols/generation-policy.json`

Writes:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`
- `Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift`
- `Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift`

Does not write:

- `Sources/CWaylandProtocols/include/wayland-client-kit-shims.h`
- `Sources/CWaylandProtocols/shims/`

### `swift run wck protocols verify-generated`

Checks diffs for:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`
- `Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift`
- `Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift`

It validates vendored XML checksums, regenerates into a temporary output tree,
validates the generation policy against the XML interface versions, and compares
that tree against the committed generated outputs. It does not write to the
checkout and does not check shim files as generated output.

### `swift run wck shims verify`

Run with `swift run wck shims verify`.

Checks the hand-written protocol and cursor shim headers and C files for the
required exported symbols used by Swift. This is intentionally separate from
protocol generation, because shim files are project-owned code rather than
scanner output.

## Boundary Rule

Generated protocol files define the protocol surface.

Shim files define the exported C surface imported by Swift.

## Adding Another Protocol

1. Add the protocol XML under `protocols/upstream/`.
2. Update `protocols/manifest.json` if the protocol should be tracked there.
3. Update `protocols/manifest.json` with the generated header and C file paths.
4. Add supported globals to `protocols/generation-policy.json`.
5. Run `swift run wck protocols generate`.
6. Add project-owned shim declarations and implementations for the Swift-facing surface.
7. Update `swift run wck shims verify` expectations for required new shim symbols.
8. Add raw Swift wrappers and tests.
9. Surface public overlay APIs only when the behavior is tested and documented.
10. Run `swift run wck ci check`.
