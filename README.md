# SwiftWayland

SwiftWayland is a Swift package for Wayland clients on Linux.

## Scope

Current experimental baseline:

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
- package-internal `DisplaySession` input draining with seat/window identity
- high-level async `WaylandDisplay` actor backed by a dedicated Wayland owner thread
  with an executor-owned integrated event loop
- copied keyboard keymap payloads inside `WaylandRaw`
- `xkbcommon`-backed key interpretation for copied `xkb_v1` keymaps through `DisplaySession`
- normal pointer cursor surfaces backed by `wayland-cursor`
- noninteractive Wayland smoke executable
- tests for system imports, shim imports, raw lifecycle, and client drawing helpers

Not implemented yet:

- protocol coverage beyond core Wayland, XDG shell, shared memory, and input basics
- compose, text-input, or IME behavior
- text input, IME, clipboard, or drag and drop protocols
- cursor animation, output-scale cursor selection, or custom cursor drawing APIs
- high-level gesture recognizers or widgets
- DocC reference documentation

## Support Matrix

Supported in the `0.0.1` checkpoint:

- `wl_display`
- `wl_registry`
- `wl_callback`
- `wl_compositor`
- `wl_surface`
- `wl_shm`
- `wl_shm_pool`
- `wl_buffer`
- `wl_seat`
- `wl_pointer`
- `wl_keyboard`
- `wl_touch`
- `xdg_wm_base`
- `xdg_surface`
- `xdg_toplevel`

Keyboard interpretation:

- `xkb_v1` keymaps through `WaylandKeyboardInterpretation` and `DisplaySession`
- key symbols and UTF-8 text derived from `xkbcommon`

Pointer cursors:

- session-level `PointerCursor` values
- static cursor surfaces from installed cursor themes through `wayland-cursor`

Not supported in the `0.0.1` checkpoint:

- `wl_data_device_manager`, clipboard, primary selection, or drag and drop
- cursor animation or per-output cursor scaling
- xdg-decoration
- presentation-time, viewporter, or fractional-scale
- linux-dmabuf, EGL, GBM, or GPU rendering
- text-input or IME protocols
- widgets or retained UI

## Reference Environment

- Fedora
- Swift 6.3.1
- `wayland-devel` for `libwayland-client` and `wayland-cursor.pc`
- `wayland-protocols-devel`
- `pkgconf-pkg-config`
- `libxkbcommon-devel`
- `git`
- `ripgrep`
- `clang`

Swift 6.3.1 must already be installed and available on `PATH` before running the bootstrap script.

## Targets

The package currently vends one library product: `WaylandClient`. The other
Swift targets are implementation modules used by that product and by tests.

```text
WaylandClient
    public Swift layer with WaylandDisplay, Window, typed events, and drawing helpers

WaylandSmokeSupport
    command parsing and runtime helper for smoke checks

SwiftWaylandSmoke
    noninteractive Wayland smoke executable

WaylandKeyboardInterpretation
    xkbcommon-backed keymap and key event interpretation

WaylandCursor
    wayland-cursor backed theme and cursor image wrapper

WaylandRaw
    low-level Swift layer, shared queue-specific event-loop engine, and raw input subsystem

WaylandRawUnsafeShim
    owner-thread executor and audited unsafe Swift runtime machinery

CWaylandUnsafeShim
    C accessors for Linux primitives used by unsafe Swift runtime machinery

CWaylandCursorShims
    C accessors for wayland-cursor structs

CWaylandCursorSystem
    system-library bridge to installed wayland-cursor headers

CWaylandProtocols
    generated protocol C + C shims

CXKBCommonSystem
    system-library bridge to installed xkbcommon headers

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

Run the raw-layer strict memory-safety file baseline:

```bash
make strict-memory-safety-raw
```

Run the unsafe-token allowlist check:

```bash
make verify-unsafe-allowlist
```

Run the demo target:

```bash
swift run swift-wayland-demo
```

The demo draws a small marker for pointer motion and prints basic pointer/keyboard/touch/seat events, including interpreted keyboard events when keymap interpretation is available.
It sets a normal pointer cursor when pointer focus enters the demo window.

Run the noninteractive Wayland smoke check under a real Wayland session:

```bash
./Scripts/smoke-wayland.sh
```

Or run the executable directly:

```bash
swift run swift-wayland-smoke
```

## Documents

- [Architecture](docs/architecture.md)
- [Protocol Generation](docs/generation.md)
- [Contributing](CONTRIBUTING.md)

## Documentation Format

Conceptual and maintenance documents are plain Markdown in the repository.

DocC is not set up yet. It can be added later for public API reference when `WaylandClient` has a stable API.
