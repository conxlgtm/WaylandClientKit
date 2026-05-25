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
- framework-host guidance and external consumer checks for packages building above `WaylandClient`
- minimal DocC catalog and public API baseline checks
- noninteractive Wayland smoke executable
- tests for system imports, shim imports, raw lifecycle, and client drawing helpers

Not implemented yet:

- protocol coverage beyond the listed current support matrix
- public cursor animation, output-scale cursor policy, or custom cursor drawing APIs
- output-management APIs
- public GPU rendering APIs in `WaylandClient`
- high-level gesture recognizers or widgets

For packages building a GUI layer on top of SwiftWayland, see
`docs/framework-host-contract.md` and `docs/building-a-gui-layer.md`.
`Examples/FrameworkHostSmoke` shows a small app-host loop without defining
widgets, layout, or a scene graph.
The framework-facing examples cover multi-window hosting, client-side resize
chrome, serial-sensitive window actions, text input, data transfer, and
presentation-feedback animation.

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
- `xdg_activation_v1`
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
- `wp_content_type_manager_v1` (package-internal preview)
- `wp_content_type_v1` (package-internal preview)
- `wp_alpha_modifier_v1` (package-internal preview)
- `wp_alpha_modifier_surface_v1` (package-internal preview)
- `wp_tearing_control_manager_v1` (package-internal preview)
- `wp_tearing_control_v1` (package-internal preview)
- `wp_color_representation_manager_v1` (package-internal preview)
- `wp_color_representation_surface_v1` (package-internal preview)
- `wp_color_manager_v1` (package-internal preview)
- `wp_color_management_surface_v1` (package-internal preview)
- `wp_color_management_surface_feedback_v1` (package-internal preview)
- `wp_color_management_output_v1` (package-internal preview)
- `wp_image_description_v1` (package-internal preview)
- `wp_image_description_reference_v1` (package-internal preview)

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
- diagonal resize cursor convenience presets are deferred until portable cursor
  theme names are verified across common compositors

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
- callers should commit enabled text-input request state before `disable()`;
  `disable()` finalizes the disable request and should not be followed by `commit()`
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
| openSUSE | `clang git libdrm-devel Mesa-libEGL-devel libgbm-devel Mesa-libGLESv2-devel wayland-devel wayland-protocols-devel libxkbcommon-devel make pkgconf-pkg-config ripgrep` |
| Alpine | `clang git libdrm-dev mesa-dev wayland-dev wayland-protocols libxkbcommon-dev make pkgconf ripgrep` |
| Gentoo | `sys-devel/clang dev-vcs/git x11-libs/libdrm media-libs/mesa dev-libs/wayland dev-libs/wayland-protocols dev-util/wayland-scanner x11-libs/libxkbcommon dev-build/make virtual/pkgconfig sys-apps/ripgrep` |
| Nix/NixOS | `nixpkgs#clang nixpkgs#git nixpkgs#libdrm nixpkgs#mesa nixpkgs#wayland nixpkgs#wayland-protocols nixpkgs#libxkbcommon nixpkgs#gnumake nixpkgs#pkg-config nixpkgs#ripgrep` |

Alpine package installation is mapped for Wayland dependencies, but Swift toolchain availability may require separate setup.
The Alpine row is a dependency lookup aid, not a Musl support claim.
Nix/NixOS support is shell/declarative: `./scripts/dev/bootstrap-linux.sh --dry-run --package-manager nix` prints a `nix shell` command, and `--install` intentionally does not mutate a Nix profile or NixOS system configuration.
On openSUSE, Swift 6.3.2 SwiftPM may require a compatibility `libxml2.so.2`
that the distro `libxml2-16` package does not provide. Project Swift wrappers
load `$SWIFT_COMPAT_LIBS` when present, defaulting to
`$HOME/.local/share/swift-compat-libs`. Tools that invoke the Swift toolchain
directly must set `LD_LIBRARY_PATH` to include that directory or make the
compatibility library available in the toolchain runtime path.

## Targets

The package currently vends `WaylandClient` and the preview
`WaylandGraphicsPreview` library product. Other Swift targets are
implementation modules used by those products and by tests.

```text
WaylandClient
    public Swift layer with WaylandDisplay, Window, typed events, and drawing helpers

WaylandGraphicsPreview
    preview graphics capability, runtime-path, and fallback value API

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

WaylandGraphicsCore
    package-internal GBM/EGL/DRM substrate for GPU preview work

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
./scripts/dev/swift.sh run SwiftWaylandDemo
```

The demo draws a small marker for pointer motion and prints basic pointer/keyboard/touch/seat events, including interpreted keyboard events when keymap interpretation is available.
Interpreted keyboard events include local compose/dead-key text results when compose support is enabled.
It sets a normal pointer cursor when pointer focus enters the demo window.

Run framework-facing examples as needed:

```bash
./scripts/dev/swift.sh run ClientSideResizeChrome
./scripts/dev/swift.sh run SerialActionsProbe
./scripts/dev/swift.sh run TwoWindowFrameworkHost -- --auto-close --print-summary
./scripts/dev/swift.sh run TwoWindowOrderStress -- --duration-seconds 3 --print-summary
./scripts/dev/swift.sh run TextInputSmoke -- --auto-close --print-summary
./scripts/dev/swift.sh run DataTransferSmoke -- --auto-close --print-summary
./scripts/dev/swift.sh run PresentationFeedbackAnimation -- --duration-seconds 3 --print-summary
./scripts/dev/swift.sh run XDGActivationSmoke
```

`ClientSideResizeChrome` demonstrates edge hit testing, resize cursors, and
serial-preserving resize requests for two windows. `SerialActionsProbe` prints
the target window, seat, serial, pointer location, decoration mode, capabilities,
and request result for move, resize, and window-menu requests. The bounded modes
let CI and release checks prove the examples still build while manual sessions
can collect compositor-specific behavior.
`XDGActivationSmoke` prints desktop activation capability; token request APIs
are not public yet.

Use [Manual Testing](docs/manual-testing.md) as the checklist for compositor
QA and record new live evidence in [Compositor Matrix](docs/compositor-matrix.md).

Run the graphics preview smoke client:

```bash
./scripts/dev/swift.sh run GPUPreviewSmokeClient
```

The graphics preview client prints a pasteable runtime-path report, creates a
managed preview backing, and submits one deterministic clear frame through the
preview submission API. The preview API does not expose raw Wayland, GBM, EGL,
DRM, or sync handles and still reports software fallback explicitly when public
managed GPU submission is unavailable.

Run the noninteractive Wayland smoke check under a real Wayland session:

```bash
./scripts/smoke/smoke-wayland.sh
```

Run public API integration tests under a real Wayland session:

```bash
./scripts/smoke/integration-wayland.sh
```

Or run the executable through the repository Swift wrapper:

```bash
./scripts/dev/swift.sh run swift-wayland-smoke
```

## Documents

- [Architecture](docs/architecture.md)
- [Protocol Generation](docs/generation.md)
- [Public API Audit](docs/public-api-audit.md)
- [Graphics Preview API](docs/graphics-preview-api.md)
- [WaylandClient DocC Catalog](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md)
- [Development Checkpoint Checklist](docs/release.md)
- [Contributing](CONTRIBUTING.md)

## Documentation Format

Conceptual and maintenance documents are plain Markdown in the repository.

The minimal `WaylandClient` DocC catalog lives beside the target in
`Sources/WaylandClient/WaylandClient.docc/`. It records the public reference
entry point while the API remains experimental.
