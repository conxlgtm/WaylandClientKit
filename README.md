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
- session-level `DisplaySession` input draining with seat/window identity
- copied keyboard keymap payloads inside `WaylandRaw`
- `xkbcommon`-backed key interpretation for copied `xkb_v1` keymaps through `DisplaySession`
- raw input async event stream
- noninteractive Wayland smoke executable
- tests for system imports, shim imports, raw lifecycle, and client drawing helpers

Not implemented yet:

- protocol coverage beyond core Wayland, XDG shell, shared memory, and input basics
- compose, text-input, or IME behavior
- cursor themes or cursor image management
- text input, IME, clipboard, or drag and drop protocols
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

Not supported in the `0.0.1` checkpoint:

- `wl_data_device_manager`, clipboard, primary selection, or drag and drop
- cursor themes or cursor surfaces
- xdg-decoration
- presentation-time, viewporter, or fractional-scale
- linux-dmabuf, EGL, GBM, or GPU rendering
- text-input or IME protocols
- widgets or retained UI

## Reference Environment

- Fedora
- Swift 6.3.1
- `wayland-devel`
- `wayland-protocols-devel`
- `pkgconf-pkg-config`
- `libxkbcommon-devel`
- `git`
- `ripgrep`
- `clang`

Swift 6.3.1 must already be installed and available on `PATH` before running the bootstrap script.

## Targets

```text
WaylandClient
    public Swift layer with DisplaySession and window helpers

WaylandSmokeSupport
    command parsing and runtime helper for smoke checks

SwiftWaylandSmoke
    noninteractive Wayland smoke executable

WaylandKeyboardInterpretation
    xkbcommon-backed keymap and key event interpretation

WaylandRaw
    low-level Swift layer and raw input subsystem

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

Run the demo target:

```bash
swift run swift-wayland-demo
```

The demo draws a small marker for pointer motion and prints basic pointer/keyboard/touch/seat events, including interpreted keyboard events when keymap interpretation is available.
It does not manage cursor images yet; some compositors may leave the cursor unchanged or undefined over the demo window.

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

DocC is not set up yet. It can be added later for public API reference when `WaylandRaw` and `WaylandClient` have stable APIs.
