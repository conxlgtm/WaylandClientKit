# Architecture

## Layer Order

```text
Application code
    |
    v
WaylandClient
    |
    v
WaylandRaw
    |
    v
CWaylandProtocols
    |
    v
CWaylandClientSystem
```

## Target Roles

### `CWaylandClientSystem`

Purpose:

- import installed Wayland client headers into SwiftPM

Contains:

- `module.modulemap`
- umbrella header for system headers

Does not contain:

- generated protocol files
- shim implementations
- project-specific runtime logic

### `CWaylandProtocols`

Purpose:

- hold project-owned C interop files

Contains:

- generated protocol headers
- generated protocol C files
- shim header
- shim C files

Subdirectories:

- `include/generated/`
- `generated/`
- `shims/`

### `WaylandRaw`

Purpose:

- low-level Swift layer

Intended contents:

- proxy wrappers
- ownership rules
- version handling
- callback lifetime handling

### `WaylandClient`

Purpose:

- public Swift layer

Current state:

- placeholder target only

## Source Categories

Repository-owned protocol inputs:

- `Protocols/`

Generated outputs:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Shim files:

- `Sources/CWaylandProtocols/include/wayforge-shims.h`
- `Sources/CWaylandProtocols/shims/`

Swift code:

- `Sources/WaylandRaw/`
- `Sources/WaylandClient/`
- `Sources/WayforgeDemo/`

## Current Checks

- `make lint`
- `make verify-generated`
- `make test`
- `make check`
