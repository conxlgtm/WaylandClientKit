# SwiftWayland

SwiftWayland is a Swift package for Wayland clients on Linux.

## Scope

Current repository scope:

- SwiftPM package layout
- system-library import of `libwayland-client`
- vendored protocol XML
- generated protocol artifacts
- C shim layer
- smoke tests for system and shim imports

Not implemented yet:

- display connection management
- Swift registry discovery
- event loop
- SHM rendering path
- visible window

## Reference Environment

- Fedora
- Swift 6.3
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
