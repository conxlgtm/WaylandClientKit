# Protocol Generation

## Inputs

Vendored XML files:

- `protocols/upstream/core/wayland.xml`
- `protocols/upstream/stable/xdg-shell/xdg-shell.xml`
- `protocols/upstream/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml`
- `protocols/upstream/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml`
- `protocols/upstream/stable/viewporter/viewporter.xml`
- `protocols/upstream/staging/fractional-scale/fractional-scale-v1.xml`
- `protocols/manifest.json`

These files are committed.

Do not edit generated files directly. Change the vendored XML or generation scripts, regenerate, and review the generated diff.

## Generated Outputs

Generated headers:

- `Sources/CWaylandProtocols/include/generated/core/wayland-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/stable/xdg-shell/xdg-shell-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/legacy-unstable/primary-selection/primary-selection-unstable-v1-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/stable/viewporter/viewporter-client-protocol.h`
- `Sources/CWaylandProtocols/include/generated/staging/fractional-scale/fractional-scale-v1-client-protocol.h`

Generated C files:

- `Sources/CWaylandProtocols/generated/core/wayland-protocol.c`
- `Sources/CWaylandProtocols/generated/stable/xdg-shell/xdg-shell-protocol.c`
- `Sources/CWaylandProtocols/generated/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-protocol.c`
- `Sources/CWaylandProtocols/generated/legacy-unstable/primary-selection/primary-selection-unstable-v1-protocol.c`
- `Sources/CWaylandProtocols/generated/stable/viewporter/viewporter-protocol.c`
- `Sources/CWaylandProtocols/generated/staging/fractional-scale/fractional-scale-v1-protocol.c`

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
./scripts/dev/bootstrap-linux.sh --maintainer
./scripts/protocols/sync.sh
```

Generate protocol artifacts from vendored XML:

```bash
./scripts/protocols/generate.sh
```

Verify that vendored XML and generated outputs are in sync:

```bash
./scripts/protocols/verify-generated.sh
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

### `scripts/protocols/sync.sh`

Copies protocol XML from the local system.

Default source resolution matches `scripts/dev/bootstrap-linux.sh --maintainer`.
The scripts first check `pkg-config` package data directories, then standard
system paths.

Core Wayland XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-client)/wayland.xml`
- `$(pkg-config --variable=pkgdatadir wayland-scanner)/wayland.xml`
- `/usr/share/wayland/wayland.xml`
- `/usr/local/share/wayland/wayland.xml`

Stable xdg-shell XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-protocols)/stable/xdg-shell/xdg-shell.xml`
- `/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml`
- `/usr/local/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml`
- `/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml`

Unstable xdg-decoration XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-protocols)/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml`
- `/usr/share/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml`
- `/usr/local/share/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml`

Unstable primary-selection XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-protocols)/unstable/primary-selection/primary-selection-unstable-v1.xml`
- `/usr/share/wayland-protocols/unstable/primary-selection/primary-selection-unstable-v1.xml`
- `/usr/local/share/wayland-protocols/unstable/primary-selection/primary-selection-unstable-v1.xml`

Stable viewporter XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-protocols)/stable/viewporter/viewporter.xml`
- `/usr/share/wayland-protocols/stable/viewporter/viewporter.xml`
- `/usr/local/share/wayland-protocols/stable/viewporter/viewporter.xml`

Staging fractional-scale XML candidates:

- `$(pkg-config --variable=pkgdatadir wayland-protocols)/staging/fractional-scale/fractional-scale-v1.xml`
- `/usr/share/wayland-protocols/staging/fractional-scale/fractional-scale-v1.xml`
- `/usr/local/share/wayland-protocols/staging/fractional-scale/fractional-scale-v1.xml`

Set `WAYLAND_CORE_XML_SOURCE`, `XDG_SHELL_XML_SOURCE`,
`XDG_DECORATION_XML_SOURCE`, `PRIMARY_SELECTION_XML_SOURCE`,
`VIEWPORTER_XML_SOURCE`, or `FRACTIONAL_SCALE_XML_SOURCE` to force a specific
source path.

Run `scripts/dev/bootstrap-linux.sh --maintainer` first to verify the scanner,
`wayland-protocols` pkg-config module, and protocol XML inputs.

### `scripts/protocols/generate.sh`

Reads:

- `protocols/`

Writes:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Does not write:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/`

### `scripts/protocols/verify-generated.sh`

Checks diffs for:

- `protocols/`
- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Does not check shim files as generated output.

### `scripts/shims/verify-shims.sh`

Run with `./scripts/shims/verify-shims.sh`.

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
3. Extend `scripts/protocols/generate.sh` to write the generated header and C file.
4. Run `./scripts/protocols/generate.sh`.
5. Add project-owned shim declarations and implementations for the Swift-facing surface.
6. Update `scripts/shims/verify-shims.sh` for required new shim symbols.
7. Add raw Swift wrappers and tests.
8. Surface public overlay APIs only when the behavior is tested and documented.
9. Run `make check`.
