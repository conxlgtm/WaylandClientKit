# Protocol Generation

## Inputs

Vendored XML files:

- `Protocols/core/wayland.xml`
- `Protocols/stable/xdg-shell/xdg-shell.xml`
- `Protocols/manifest.json`

These files are committed.

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

## Commands

Sync XML from the local system:

```bash
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

## Script Responsibilities

### `Scripts/sync-protocols.sh`

Copies:

- `/usr/share/wayland/wayland.xml`
- `/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml`

Fallback for `xdg-shell.xml`:

- `/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml`

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

## Boundary Rule

Generated protocol files define the protocol surface.

Shim files define the exported C surface imported by Swift.
