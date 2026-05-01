# Protocol Generation

## Inputs

Vendored XML files:

- `Protocols/core/wayland.xml`
- `Protocols/stable/xdg-shell/xdg-shell.xml`
- `Protocols/manifest.json`

These files are committed.

Do not edit generated files directly. Change the vendored XML or generation scripts, regenerate, and review the generated diff.

## Generated Outputs

Generated headers:

- `Sources/CWaylandProtocols/include/generated/wayland-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/xdg-shell-client-protocol.h`

Generated C files:

- `Sources/CWaylandProtocols/generated/wayland-protocol.c`
- `Sources/CWaylandProtocols/generated/xdg-shell-protocol.c`

These files are committed.

## Shim Files

These files are not generated:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/*.c`

## Tools

- `wayland-scanner`
- `git`
- `ripgrep`
- `pkg-config`

## Commands

Sync XML from the local system:

```bash
./Scripts/bootstrap-linux.sh --maintainer
./Scripts/sync-protocols.sh
```

Generate protocol artifacts from vendored XML:

```bash
./Scripts/generate-protocols.sh
```

Verify that vendored XML and generated outputs are in sync:

```bash
./Scripts/verify-generated.sh
```

Run the full local gate:

```bash
make check
```

Verify the hand-written C shim declarations and implementations cover the
currently-supported Swift surface:

```bash
make verify-shims
```

## Script Responsibilities

### `Scripts/sync-protocols.sh`

Copies protocol XML from the local system.

Default sources:

- `/usr/share/wayland/wayland.xml`
- `/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml`

Fallback for `xdg-shell.xml`:

- `/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml`

Run `Scripts/bootstrap-linux.sh --maintainer` first to verify the scanner,
`wayland-protocols` pkg-config module, and protocol XML inputs.

### `Scripts/generate-protocols.sh`

Reads:

- `Protocols/`

Writes:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Does not write:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/`

### `Scripts/verify-generated.sh`

Checks diffs for:

- `Protocols/`
- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Does not check shim files as generated output.

### `Scripts/verify-shims.sh`

Run with `./Scripts/verify-shims.sh`.

Checks the hand-written protocol and cursor shim headers and C files for the
required exported symbols used by Swift. This is intentionally separate from
protocol generation, because shim files are project-owned code rather than
scanner output.

## Boundary Rule

Generated protocol files define the protocol surface.

Shim files define the exported C surface imported by Swift.

## Adding Another Protocol

1. Add the protocol XML under `Protocols/`.
2. Update `Protocols/manifest.json` if the protocol should be tracked there.
3. Extend `Scripts/generate-protocols.sh` to write the generated header and C file.
4. Run `./Scripts/generate-protocols.sh`.
5. Add project-owned shim declarations and implementations for the Swift-facing surface.
6. Update `Scripts/verify-shims.sh` for required new shim symbols.
7. Add raw Swift wrappers and tests.
8. Surface public overlay APIs only when the behavior is tested and documented.
9. Run `make check`.
