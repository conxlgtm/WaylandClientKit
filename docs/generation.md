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
Run `swift run swl protocols list` to print the tracked inventory.

Do not edit generated files directly. Change the vendored XML or protocol manifest metadata, regenerate, and review the generated diff.

## Generated Outputs

Generated headers:

- `Sources/CWaylandProtocols/include/generated/`

Generated C files:

- `Sources/CWaylandProtocols/generated/`

These files are committed. The exact file set comes from `generatedHeaderPath`
and `generatedCodePath` in `protocols/manifest.json`.

## Shim Files

These files are not generated:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/*.c`

## Tools

- `wayland-scanner`
- `ripgrep`
- `pkg-config`

## Commands

Sync XML from the local system:

```bash
swift run swl bootstrap maintainer-check
swift run swl protocols sync
```

Generate protocol artifacts from vendored XML:

```bash
swift run swl protocols generate
```

Verify that vendored XML and generated outputs are in sync:

```bash
swift run swl protocols verify-generated
```

Verify that every manifest entry records tier, exposure, and test policy:

```bash
swift run swl protocols verify-manifest
```

Run the full local gate:

```bash
swift run swl ci check
```

Verify the hand-written C shim declarations and implementations cover the
currently-supported Swift surface:

```bash
swift run swl shims verify
```

Verify DocC symbol references:

```bash
swift run swl docc verify-symbol-links
```

## Command Responsibilities

### `swift run swl protocols sync`

Copies protocol XML from the local system.

Default source resolution matches `protocols/manifest.json`. The command checks
the manifest override environment variable, pkg-config package data directory
plus relative candidates, absolute fallback candidates, and finally the
checked-in vendored XML. The selected source must match the manifest checksum
before it is copied.

Run `swift run swl protocols sources` to print the selected source for every
manifest entry without copying files.

Run `swift run swl bootstrap maintainer-check` first to verify the scanner,
`wayland-protocols` pkg-config module, and protocol XML inputs.

### `swift run swl protocols generate`

Reads:

- `protocols/`

Writes:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Does not write:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/`

### `swift run swl protocols verify-generated`

Checks diffs for:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

It validates vendored XML checksums, regenerates into a temporary output tree,
and compares that tree against the committed generated outputs. It does not
write to the checkout and does not check shim files as generated output.

### `swift run swl shims verify`

Run with `swift run swl shims verify`.

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
4. Run `swift run swl protocols generate`.
5. Add project-owned shim declarations and implementations for the Swift-facing surface.
6. Update `swift run swl shims verify` expectations for required new shim symbols.
7. Add raw Swift wrappers and tests.
8. Surface public overlay APIs only when the behavior is tested and documented.
9. Run `swift run swl ci check`.
