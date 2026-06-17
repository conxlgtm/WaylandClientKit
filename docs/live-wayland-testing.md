# Linux Live Wayland Testing

WaylandClientKit has two live Wayland test paths:

- real compositor testing, where tests connect to the caller's current `WAYLAND_DISPLAY`
- headless Weston testing, where the test command starts a private compositor

Use the headless path for CI and repeatable local smoke checks. Use the real
compositor path when checking behavior against a desktop session such as KDE or
GNOME.

## Commands

```bash
swift run wck smoke live
swift run wck smoke integration
swift run wck smoke gpu-preview
swift run wck smoke headless -- wck smoke live
swift run wck smoke headless -- wck smoke integration
swift run wck smoke headless -- wck smoke gpu-preview
swift run wck compositor evidence-summary
swift run wck ci check
swift run wck ci release
swift run wck test integration-graphics-preview
swift run wck tools toolchain-smoke
swift test --filter WaylandThreadExecutorConcurrencyTests --no-parallel
```

`swift run wck smoke live` runs the `wayland-client-kit-smoke` executable against the
current compositor. It requires `WAYLAND_DISPLAY`.

`swift run wck smoke integration` runs the external public API integration package
against the current compositor. It requires `WAYLAND_DISPLAY` and sets
`WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS=1`.

`swift run wck test integration-graphics-preview` runs an external compile/test package for
the `WaylandGraphicsPreview` product. It does not require a live compositor or a
GPU-capable session.

`swift run wck smoke gpu-preview` runs package-internal GPU preview checks against the
current compositor. It requires `WAYLAND_DISPLAY`, sets
`WAYLAND_CLIENT_KIT_ENABLE_GPU_PREVIEW_TESTS=1`, and enables the GBM/EGL smoke path
with `WCK_RUN_GPU_SMOKE=1`. The current test path proves the linux-dmabuf
capability gate, public graphics fact projection, explicit software fallback
projection, and a local GBM/EGL clear plus dmabuf export when an accessible DRM
render node is present. It also runs `GPUPreviewSmokeClient`, which prints a
pasteable `WaylandClientKit GPU Preview Runtime Path` block for
[compositor-matrix.md](compositor-matrix.md).

The command runs `swift run wck smoke gpu-preview`.

`swift run wck smoke headless -- wck smoke live` starts headless Weston, then
runs the noninteractive smoke executable against that private compositor.

`swift run wck smoke headless -- wck smoke integration` starts headless Weston and runs the env-gated
window-control and source-side drag request-path tests against that private
compositor. It sets `WAYLAND_CLIENT_KIT_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1` and
`WAYLAND_CLIENT_KIT_ENABLE_DND_SOURCE_REQUEST_TESTS=1`.

`swift run wck test tsan` and `swift run wck test asan` run the sanitizer test
gates. GPU hardware paths remain separate from sanitizer jobs.

`swift run wck smoke headless -- wck smoke gpu-preview` starts headless Weston, then runs the GPU preview
capability, graphics fact projection, pasteable runtime-path report, and
GBM/EGL smoke path against that private compositor. The render-node-dependent
portion reports a skip/fact when the private CI environment has no accessible
DRM render node.

`swift run wck ci check` runs the normal local check set. It runs the live Wayland smoke
check only when `WAYLAND_DISPLAY` is already set.

`swift run wck ci release` runs the base check set first. After that, it uses the
current compositor when `WAYLAND_DISPLAY` is set, uses headless Weston when
`weston` is installed, and fails in CI or when `REQUIRE_WAYLAND_SMOKE=1` if no
live Wayland path is available.

`swift run wck tools toolchain-smoke` reports the active Swift wrapper,
`Package.swift` tools version, optional `SWIFT_NEXT_BIN` status, and the
allowed-failure Swift Build preview status. Native SwiftPM remains the supported
build system.

`swift run wck compositor evidence-summary` summarizes the current
`docs/compositor-matrix.md` rows so missing evidence is visible before release
notes or checkpoint notes are written.

Use repeated `swift test --filter ... --no-parallel` runs for local stress
validation before promoting a scheduler, event-loop, or descriptor-lifecycle
change.

## Headless Weston

The headless wrapper owns the runtime setup for live tests:

- creates a private `XDG_RUNTIME_DIR`
- creates a private `WAYLAND_DISPLAY` socket name
- sets an isolated `XDG_CONFIG_HOME`
- unsets inherited `WAYLAND_SOCKET`
- starts Weston with `--backend=headless-backend.so`
- waits for the socket before running tests
- captures Weston logs
- kills and reaps Weston on exit
- removes the temporary runtime directory

The wrapper prints Weston logs only when the command fails. Successful runs
should show test output, not compositor startup noise.

## Packages

Build requirements are listed in [README.md](../README.md). Live headless tests
also need Weston.

Ubuntu/Debian:

```bash
sudo apt-get install \
  clang git ripgrep pkg-config \
  libdrm-dev libegl-dev libgbm-dev libgles-dev \
  libwayland-bin libwayland-dev libxkbcommon-dev \
  wayland-protocols \
  weston
```

Fedora/RHEL-like:

```bash
sudo dnf install \
  clang git ripgrep \
  pkgconf-pkg-config \
  libdrm-devel mesa-libEGL-devel mesa-libgbm-devel mesa-libGLES-devel \
  wayland-devel wayland-protocols-devel \
  libxkbcommon-devel \
  weston
```

openSUSE:

```bash
sudo zypper --non-interactive install \
  clang git ripgrep \
  pkgconf-pkg-config \
  libdrm-devel Mesa-libEGL-devel libgbm-devel Mesa-libGLESv2-devel \
  wayland-devel wayland-protocols-devel \
  libxkbcommon-devel \
  weston
```

Swift 6.3.2 SwiftPM may also need a compatibility `libxml2.so.2` on
openSUSE. The Swift tool resolver honors `$SWIFT_COMPAT_LIBS`, defaulting to
`$HOME/.local/share/swift-compat-libs`, direct toolchain calls must expose that
directory through `LD_LIBRARY_PATH` or another runtime loader path.

The support contract is SwiftPM plus system libraries resolved through
`pkg-config`. Distro package files are not part of the current repository.

## Optional Protocol Policy

Live tests distinguish required globals from optional protocol coverage.

Required baseline globals should fail when absent:

- `wl_compositor`
- `wl_shm`
- `xdg_wm_base`

Optional protocol-specific live tests should skip when the compositor does not
advertise the protocol, and should fail when the compositor advertises the
protocol but the tested behavior is broken.

Optional protocol skip messages should name the exact missing interface:

```text
Skipping primary selection live test: compositor did not advertise zwp_primary_selection_device_manager_v1.
Skipping fractional scale live test: compositor did not advertise wp_fractional_scale_manager_v1.
Skipping xdg-decoration live test: compositor did not advertise zxdg_decoration_manager_v1.
Skipping viewporter live test: compositor did not advertise wp_viewporter.
Skipping presentation-time live test: compositor did not advertise wp_presentation.
Skipping linux-dmabuf live test: compositor did not advertise zwp_linux_dmabuf_v1.
Skipping syncobj live test: compositor did not advertise wp_linux_drm_syncobj_manager_v1.
Skipping FIFO live test: compositor did not advertise wp_fifo_manager_v1.
Skipping commit-timing live test: compositor did not advertise wp_commit_timing_manager_v1.
Skipping content-type live test: compositor did not advertise wp_content_type_manager_v1.
Skipping alpha-modifier live test: compositor did not advertise wp_alpha_modifier_v1.
Skipping tearing-control live test: compositor did not advertise wp_tearing_control_manager_v1.
Skipping color-representation live test: compositor did not advertise wp_color_representation_manager_v1.
Skipping color-management live test: compositor did not advertise wp_color_manager_v1.
Skipping GPU preview live test: compositor did not advertise zwp_linux_dmabuf_v1.
Skipping cursor-shape live test: compositor did not advertise wp_cursor_shape_manager_v1.
Skipping text-input live test: compositor did not advertise zwp_text_input_manager_v3.
```

Do not hide an advertised-but-broken protocol behind a skip. That is a client
or compositor behavior failure, and the test should report it as such.
