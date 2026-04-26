# SwiftWayland

SwiftWayland is a Swift package for Wayland clients on Linux.

## Scope

Current repository scope:

- SwiftPM package layout
- system-library import of `libwayland-client`
- vendored protocol XML
- generated protocol artifacts
- C shim layer
- display connection management
- registry discovery and version negotiation
- event loop integration
- SHM software rendering path
- XDG toplevel window creation/configure handling
- frame callback pacing
- seat, pointer, keyboard, and touch event capture
- raw input async event stream
- tests for system imports, shim imports, raw lifecycle, and client drawing helpers

Not implemented yet:

- protocol coverage beyond core Wayland, XDG shell, shared memory, and input basics
- xkbcommon-backed keyboard text/layout interpretation
- higher-level `WaylandClient` async event adapters
- DocC reference documentation

## Reference Environment

- Fedora
- Swift 6.3.1
- `wayland-devel`
- `wayland-protocols-devel`
- `pkgconf-pkg-config`

## Targets

```text
WaylandClient
    public Swift layer

WaylandRaw
    low-level Swift layer

CWaylandProtocols
    generated protocol C + C shims

CWaylandClientSystem
    system-library bridge to installed Wayland headers
```

## Commands

Bootstrap the Fedora environment:

```bash
./Scripts/bootstrap-fedora.sh
```

Sync protocol XML into the repository:

```bash
./Scripts/sync-protocols.sh
```

Regenerate protocol artifacts:

```bash
./Scripts/generate-protocols.sh
```

Run local checks:

```bash
make check
```

Run the strict Swift concurrency build only:

```bash
make strict-concurrency
```

Run the demo target:

```bash
swift run swift-wayland-demo
```

## Documents

- [Architecture](docs/architecture.md)
- [Protocol Generation](docs/generation.md)

## Documentation Format

Conceptual and maintenance documents are plain Markdown in the repository.

DocC is not set up yet. It can be added later for public API reference when `WaylandRaw` and `WaylandClient` have stable APIs.
