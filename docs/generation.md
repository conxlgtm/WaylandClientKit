# Protocol Generation

Generated files are updated through vendored XML or policy metadata. Run the
generator and review its diff rather than editing generated output directly.

## Inputs And Policies

Protocol XML is vendored under:

- `protocols/upstream/core/`
- `protocols/upstream/stable/`
- `protocols/upstream/staging/`
- `protocols/upstream/legacy-unstable/`

The generator reads these policy files:

| File | Contents |
| --- | --- |
| `protocols/manifest.json` | XML location, checksum, generated paths, scanner modes, tier, API exposure, and test strategy |
| `protocols/generation-policy.json` | supported version caps, required and optional globals, retained wrappers, and registry bind bridges |
| `protocols/listener-bridge-policy.json` | listener callback bundles, exported shim names, and handwritten exceptions |
| `protocols/request-bridge-policy.json` | direct request wrappers, exported C names, and handwritten exceptions |

`WaylandProtocolXMLParser` parses all XML before writing output. The intermediate
model preserves interface order, versions, requests, events, arguments, opcodes,
destructors, and enumerations.

The XML supplies protocol facts. JSON policy supplies client decisions such as
version caps, minimum bindable versions, optional-global retention, capability
reporting, queue ownership, and shim naming.

Requests with test recording, failure injection, conversions, version checks,
or ownership behavior remain handwritten. Direct XML-defined requests may use
generated bridges.

## Outputs

The generator writes committed files under:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`
- `Sources/WaylandRaw/Internal/Binding/OptionalGlobalDescriptors.swift`
- `Sources/WaylandRaw/Internal/Binding/SupportedVersions.swift`

The umbrella header and special-case shims remain handwritten:

- `Sources/CWaylandProtocols/include/wayland-client-kit-shims.h`
- `Sources/CWaylandProtocols/shims/*.c`

## Commands

| Command | Effect |
| --- | --- |
| `swift run wck protocols list` | Prints the manifest inventory. |
| `swift run wck protocols sources` | Resolves XML sources without copying files. |
| `swift run wck protocols sync` | Copies checksum-matched XML from the resolved local source. |
| `swift run wck protocols generate` | Regenerates C, headers, global descriptors, and supported versions. |
| `swift run wck protocols verify-generated` | Regenerates in a temporary tree and compares it with committed output. |
| `swift run wck protocols verify-manifest` | Checks manifest tier, exposure, and test metadata. |
| `swift run wck shims verify` | Checks exported handwritten and generated shim symbols used by Swift. |
| `swift run wck docc verify-symbol-links` | Checks DocC symbol references. |

Run `swift run wck bootstrap maintainer-check` before synchronization or
generation. It checks `wayland-scanner`, the `wayland-protocols` pkg-config
module, and required XML inputs.

Source resolution checks the manifest override environment variable,
pkg-config data directories, absolute fallback paths, then vendored XML. A
source must match the manifest checksum before `sync` copies it.

`verify-generated` validates XML checksums and policies, regenerates all declared
outputs, and compares the temporary tree with the checkout. It does not write to
the checkout.

See [Tooling](tooling.md) for command ownership.

## Adding A Protocol

1. Add XML under `protocols/upstream/`.
2. Add its checksum, generated paths, tier, exposure, and test strategy to
   `protocols/manifest.json`.
3. Add supported globals to `protocols/generation-policy.json`.
4. Classify listener and request bridges in their policy files.
5. Run `swift run wck protocols generate`.
6. Add handwritten shims only for behavior not described by XML and naming
   policy.
7. Add raw Swift wrappers, tests, and public docs when applicable.
8. Run `swift run wck ci check`.
