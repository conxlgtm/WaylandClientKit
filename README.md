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
- scale-aware surface geometry for software rendering
- XDG toplevel window creation/configure handling
- xdg-decoration server-side decoration negotiation
- viewporter and fractional-scale protocol integration for scaled SHM buffers
- frame callback pacing
- seat, pointer, keyboard, and touch event capture
- popup surfaces with placement, redraw, dismissal, and input target identity
- package-internal `DisplaySession` input draining with seat/window identity
- high-level async `WaylandDisplay.withConnection` API backed by a dedicated Wayland owner
  thread with an executor-owned integrated event loop
- copied keyboard keymap payloads inside `WaylandRaw`
- `xkbcommon`-backed key interpretation for copied `xkb_v1` keymaps through `DisplaySession`
- normal pointer cursor surfaces backed by `wayland-cursor`
- regular clipboard selection offers and sources through `wl_data_device_manager`
- primary selection offers and sources through `zwp_primary_selection_device_manager_v1`
- compositor/IME text entry through `zwp_text_input_manager_v3`
- compositor cursor-shape requests through `wp_cursor_shape_manager_v1`
- explicit compositor presentation feedback through `wp_presentation`
- linux-dmabuf capability discovery and package-internal GBM/EGL preview pieces
- compose and dead-key text results for interpreted keyboard events
- display, input, data-transfer, text-input, and diagnostic event streams
- minimal DocC catalog and public API baseline checks
- noninteractive Wayland smoke executable
- tests for system imports, shim imports, raw lifecycle, and client drawing helpers

Not implemented yet:

- protocol coverage beyond the listed current support matrix
- public cursor animation, output-scale cursor policy, or custom cursor drawing APIs
- output-management APIs
- public GPU rendering APIs in `WaylandClient`
- high-level gesture recognizers or widgets

## Support Matrix

Supported in the current experimental baseline:

- `wl_display`
- `wl_registry`
- `wl_callback`
- `wl_compositor`
- `wl_surface`
- `wl_output`
- `wl_shm`
- `wl_shm_pool`
- `wl_buffer`
- `wl_seat`
- `wl_pointer`
- `wl_keyboard`
- `wl_touch`
- `wl_data_device_manager`
- `wl_data_device`
- `wl_data_offer`
- `wl_data_source`
- `zwp_primary_selection_device_manager_v1`
- `zwp_primary_selection_device_v1`
- `zwp_primary_selection_offer_v1`
- `zwp_primary_selection_source_v1`
- `xdg_wm_base`
- `xdg_surface`
- `xdg_toplevel`
- `xdg_popup`
- `xdg_positioner`
- `zxdg_decoration_manager_v1`
- `zxdg_toplevel_decoration_v1`
- `zxdg_output_manager_v1`
- `zxdg_output_v1`
- `wp_viewporter`
- `wp_viewport`
- `wp_presentation`
- `wp_presentation_feedback`
- `wp_fractional_scale_manager_v1`
- `wp_fractional_scale_v1`
- `wp_cursor_shape_manager_v1`
- `wp_cursor_shape_device_v1`
- `zwp_text_input_manager_v3`
- `zwp_text_input_v3`
- `zwp_linux_dmabuf_v1`
- `zwp_linux_dmabuf_feedback_v1`
- `zwp_linux_buffer_params_v1`
- `wp_linux_drm_syncobj_manager_v1` (package-internal preview)
- `wp_linux_drm_syncobj_surface_v1` (package-internal preview)
- `wp_linux_drm_syncobj_timeline_v1` (package-internal preview)
- `wp_fifo_manager_v1` (package-internal preview)
- `wp_fifo_v1` (package-internal preview)
- `wp_commit_timing_manager_v1` (package-internal preview)
- `wp_commit_timer_v1` (package-internal preview)

Window geometry:

- window configuration and xdg configure sizes are logical surface units
- `SurfaceScale` stores exact rational scale values
- `SurfaceGeometry` reports logical size, buffer-pixel size, and scale
- `SoftwareFrame.width` and `SoftwareFrame.height` are buffer-pixel dimensions
- `SoftwareFrame.geometry` reports how those pixels map back to logical surface size

Keyboard interpretation:

- `xkb_v1` keymaps through `WaylandKeyboard` and `DisplaySession`
- key symbol lists, primary key symbols, and UTF-8 key text derived from `xkbcommon`
- compose and dead-key sequences through `xkbcommon` compose state
- shortcut logic should use key symbols and modifiers, not composed text
- composed text is local keyboard text and is separate from Wayland text-input
  or IME output

Pointer cursors:

- session-level `PointerCursor` values
- compositor-managed cursor-shape requests when advertised and mapped
- static cursor surfaces from installed cursor themes through `wayland-cursor`

Clipboard and data transfer:

- regular clipboard selection offers can be inspected and received
- regular clipboard sources can be offered and cleared
- compositor support for clipboard, primary selection, decorations, viewporter,
  and fractional scaling can be inspected through `WaylandDisplay.capabilities()`
- primary selection offers can be inspected and received when the compositor advertises the protocol
- primary selection sources can be offered and cleared with an input serial
- primary selection is selection-driven and focus-sensitive, not a second regular clipboard
- receive-side drag-and-drop offers can be inspected, negotiated, received, finished, and cancelled
- source-side drag-and-drop sources can be started and cancelled from managed windows with explicit input serials
- drag source target, action, drop, finished, and cancelled lifecycle events are exposed
- source-side drags can use managed XRGB8888 drag icon surfaces

Text input:

- `WaylandDisplay.textInputSession(for:)` creates seat-scoped text-input sessions
- `WaylandDisplay.textInputEvents` publishes compositor/IME text-input events
- surrounding text, content type, change cause, cursor rectangle, enable, disable,
  and commit requests are protocol-shaped
- text-input is separate from local keyboard interpretation and shortcut state

Outputs:

- public output snapshots report scale, transform, physical size, make, model, name, and description when advertised
- output add, update, and remove events are exposed through the display event stream
- window output membership tracks `wl_surface.enter` and `wl_surface.leave`
- `zxdg_output_manager_v1` logical output geometry is reported when the compositor advertises version 2 or newer

Presentation timing:

- `WaylandDisplay.capabilities()` reports optional `wp_presentation` availability
- managed windows can request explicit presentation feedback after being configured
- presentation feedback reports timestamp, refresh estimate, sequence, flags, and synchronized output when available
- missing `wp_presentation` is reported as unavailable; frame callbacks are not treated as fake presentation feedback

Popups:

- popup surfaces can be created from windows
- popup placement is reported through `PopupSurface.placement`
- popup lifecycle events identify the popup and parent window
- input events preserve popup target identity

Not supported in the current experimental baseline:

- public cursor animation or per-output cursor policy APIs
- output management or control APIs
- public `WaylandClient` GPU rendering APIs
- public explicit synchronization or frame-pacing APIs
- widgets or retained UI

## Linux Dependencies

Swift 6.3.2 or newer must already be installed.
The bootstrap script verifies Swift through `scripts/dev/swift.sh` by default.
It does not install or switch toolchains.
Set `SWIFT_COMMAND=/path/to/swift` for custom toolchain resolution.

Current CI validates dynamic glibc Linux on Ubuntu Noble with shared libraries
resolved through `pkg-config`. Musl, static Linux SDK builds, and static linking
are not part of the current support contract.

The build dependency source of truth is the system capability surface:

- Swift 6.3.2 or newer
- `clang`
- `pkg-config`
- `pkg-config --exists egl`
- `pkg-config --exists gbm`
- `pkg-config --exists glesv2`
- `pkg-config --exists libdrm`
- `pkg-config --exists wayland-client`
- `pkg-config --exists wayland-cursor`
- `pkg-config --exists xkbcommon`

Maintainers regenerating protocol artifacts also need:

- `wayland-scanner`
- `pkg-config --exists wayland-protocols`
- `wayland.xml`
- `stable/xdg-shell/xdg-shell.xml`

Supported package-manager mappings:

| Family | Packages |
| --- | --- |
| Debian/Ubuntu | `clang git libdrm-dev libegl-dev libgbm-dev libgles-dev libwayland-dev libxkbcommon-dev make pkg-config ripgrep wayland-protocols` |
| Fedora/RHEL-like | `clang git libdrm-devel mesa-libEGL-devel mesa-libgbm-devel mesa-libGLES-devel wayland-devel wayland-protocols-devel libxkbcommon-devel make pkgconf-pkg-config ripgrep` |
| Arch/Manjaro | `clang git libdrm mesa wayland wayland-protocols libxkbcommon make pkgconf ripgrep` |
| openSUSE | `clang git libdrm-devel Mesa-libEGL-devel Mesa-libgbm-devel Mesa-libGLESv2-devel wayland-devel wayland-protocols-devel libxkbcommon-devel make pkgconf-pkg-config ripgrep` |
| Alpine | `clang git libdrm-dev mesa-dev wayland-dev wayland-protocols libxkbcommon-dev make pkgconf ripgrep` |
| Gentoo | `sys-devel/clang dev-vcs/git x11-libs/libdrm media-libs/mesa dev-libs/wayland dev-libs/wayland-protocols dev-util/wayland-scanner x11-libs/libxkbcommon dev-build/make virtual/pkgconfig sys-apps/ripgrep` |
| Nix/NixOS | `nixpkgs#clang nixpkgs#git nixpkgs#libdrm nixpkgs#mesa nixpkgs#wayland nixpkgs#wayland-protocols nixpkgs#libxkbcommon nixpkgs#gnumake nixpkgs#pkg-config nixpkgs#ripgrep` |

Alpine package installation is mapped for Wayland dependencies, but Swift toolchain availability may require separate setup.
The Alpine row is a dependency lookup aid, not a Musl support claim.
Nix/NixOS support is shell/declarative: `./scripts/dev/bootstrap-linux.sh --dry-run --package-manager nix` prints a `nix shell` command, and `--install` intentionally does not mutate a Nix profile or NixOS system configuration.

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

WaylandKeyboard
    xkbcommon-backed keymap and key event interpretation

WaylandCursor
    wayland-cursor backed theme and cursor image wrapper

WaylandRaw
    low-level Swift layer, shared queue-specific event-loop engine, and raw input subsystem

WaylandRuntime
    owner-thread executor and audited unsafe Swift runtime machinery

CWaylandRuntimeShims
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

Verify or bootstrap a Linux environment:

```bash
./scripts/dev/bootstrap-linux.sh --check
./scripts/dev/bootstrap-linux.sh --dry-run
./scripts/dev/bootstrap-linux.sh --dry-run --package-manager nix
./scripts/dev/bootstrap-linux.sh --install
./scripts/dev/bootstrap-linux.sh --build
```

Maintainers regenerating protocol artifacts should also run:

```bash
./scripts/dev/bootstrap-linux.sh --maintainer
```

Live Wayland smoke and public API integration checks are documented in
[Linux live Wayland testing](docs/live-wayland-testing.md).

Run the headless Weston path with:

```bash
make wayland-headless
```

Sync protocol XML into the repository:

```bash
./scripts/protocols/sync.sh
```

Regenerate protocol artifacts:

```bash
./scripts/protocols/generate.sh
```

Run local checks:

```bash
make check
```

Run the strict Swift concurrency build only:

```bash
make strict-concurrency
```

Generate a public API report before publishing checkpoint notes:

```bash
./scripts/ci/dump-public-api.sh
```

Run the unsafe-token allowlist check:

```bash
make verify-unsafe-allowlist
```

Run the demo target:

```bash
swift run SwiftWaylandDemo
```

The demo draws a small marker for pointer motion and prints basic pointer/keyboard/touch/seat events, including interpreted keyboard events when keymap interpretation is available.
Interpreted keyboard events include local compose/dead-key text results when compose support is enabled.
It sets a normal pointer cursor when pointer focus enters the demo window.

Run the noninteractive Wayland smoke check under a real Wayland session:

```bash
./scripts/smoke/smoke-wayland.sh
```

Run public API integration tests under a real Wayland session:

```bash
./scripts/smoke/integration-wayland.sh
```

Or run the executable directly:

```bash
swift run swift-wayland-smoke
```

## Documents

- [Architecture](docs/architecture.md)
- [Protocol Generation](docs/generation.md)
- [Public API Audit](docs/public-api-audit.md)
- [WaylandClient DocC Catalog](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md)
- [Development Checkpoint Checklist](docs/release.md)
- [Contributing](CONTRIBUTING.md)

## Documentation Format

Conceptual and maintenance documents are plain Markdown in the repository.

The minimal `WaylandClient` DocC catalog lives beside the target in
`Sources/WaylandClient/WaylandClient.docc/`. It records the public reference
entry point while the API remains experimental.
