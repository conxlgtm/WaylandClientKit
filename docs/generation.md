# Protocol Generation

## Inputs

Vendored XML files:

- `protocols/upstream/core/`
- `protocols/upstream/stable/`
- `protocols/upstream/staging/`
- `protocols/upstream/legacy-unstable/`
- `protocols/manifest.json`
- `protocols/generation-policy.json`
- `protocols/listener-bridge-policy.json`
- `protocols/request-bridge-policy.json`

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

The generator uses `wayland-scanner` for the native protocol declarations and C
code. It generates `SupportedVersions.swift` and optional-global ownership from
the parsed interface versions and `protocols/generation-policy.json`. That policy
records the client version cap, any non-default minimum version, and whether each
supported global is required or optional. For optional globals, it also records
whether the public capability inventory reports the interface. An optional
global retained for the display lifetime records its wrapper type, stored
property, binding method, and acquisition order. The same global entries select
the generated C registry bind bridges. Their Swift callers still own version
negotiation, queue assignment, adoption, rollback, and destruction.

`protocols/listener-bridge-policy.json` selects the listener callback bundles
used by the Swift raw layer. The XML supplies event order and C wire types. The
policy preserves the existing exported shim names, records the one intentionally
omitted surface event, and marks installers that keep handwritten test or system
header behavior. Normal listener forwarding comes from the same XML model.

`protocols/request-bridge-policy.json` selects ordinary request wrappers that
can call the XML-defined request directly. The XML supplies their argument and
return types. The policy keeps existing C names and classifies requests that
stay handwritten because they record tests, inject failures, handle version or
ownership rules, convert values, or aren't exposed by the shim API.

## Generated Outputs

Generated headers:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/include/generated/shims/listener-bridges.h`
- `Sources/CWaylandProtocols/include/generated/shims/registry-bind-bridges.h`
- `Sources/CWaylandProtocols/include/generated/shims/request-bridges.h`

Generated C files:

- `Sources/CWaylandProtocols/generated/`
- `Sources/CWaylandProtocols/generated/shims/listener-bridges.c`
- `Sources/CWaylandProtocols/generated/shims/registry-bind-bridges.c`
- `Sources/CWaylandProtocols/generated/shims/request-bridges.c`

Generated Swift files:

- `Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift`
- `Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift`

These files are committed. The exact file set comes from `generatedHeaderPath`
and `generatedCodePath` in `protocols/manifest.json`, plus the supported globals
and their registry bind bridges in `protocols/generation-policy.json`, and the
listener inventory in `protocols/listener-bridge-policy.json`.
The direct request-wrapper inventory and its naming exceptions come from
`protocols/request-bridge-policy.json`.

## Shim Files

The umbrella header and special-case shim implementations remain handwritten:

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
- `protocols/listener-bridge-policy.json`
- `protocols/request-bridge-policy.json`

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
validates the generation policies against the XML schema, and compares
that tree against the committed generated outputs, including the listener
bridge, registry bind bridge, and ordinary request bridge headers and C
implementations. It does not write to the checkout.

### `swift run wck shims verify`

Run with `swift run wck shims verify`.

Checks the handwritten protocol and cursor shim files, plus the generated shim
headers, for the required exported symbols used by Swift. This stays separate
from protocol generation because requests with test hooks, conversions,
failure injection, version checks, or ownership behavior remain project-owned.

## Boundary Rule

Generated protocol files and schema-shaped bridges define the protocol surface.

Generated request bridges and handwritten shim files together define the C
surface imported by Swift. A request belongs in generated output only when its
wrapper is a direct call described completely by the XML and naming policy.

## Adding Another Protocol

1. Add the protocol XML under `protocols/upstream/`.
2. Update `protocols/manifest.json` if the protocol should be tracked there.
3. Update `protocols/manifest.json` with the generated header and C file paths.
4. Add supported globals to `protocols/generation-policy.json`.
5. Run `swift run wck protocols generate`.
6. Classify request wrappers in `protocols/request-bridge-policy.json`.
7. Add project-owned request shims only when the wrapper owns behavior beyond a direct XML request.
8. Update `swift run wck shims verify` expectations for required new shim symbols.
9. Add raw Swift wrappers and tests.
10. Surface public overlay APIs only when the behavior is tested and documented.
11. Run `swift run wck ci check`.
