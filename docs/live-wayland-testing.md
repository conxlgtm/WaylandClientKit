# Linux Live Wayland Testing

SwiftWayland has two live Wayland test paths:

- real compositor testing, where tests connect to the caller's current `WAYLAND_DISPLAY`
- headless Weston testing, where the test command starts a private compositor

Use the headless path for CI and repeatable local smoke checks. Use the real
compositor path when checking behavior against a desktop session such as KDE or
GNOME.

## Commands

```bash
make smoke-wayland
make integration-wayland
make gpu-preview-wayland
make wayland-headless
make wayland-request-headless
make wayland-request-headless-tsan
make wayland-request-headless-asan
make gpu-preview-headless
make check
make release-check
make test-graphics-preview-client
make swiftbuild-smoke
./scripts/ci/repeat-test.sh --count 20 --filter WaylandThreadExecutorConcurrencyTests
```

`make smoke-wayland` runs the `swift-wayland-smoke` executable against the
current compositor. It requires `WAYLAND_DISPLAY`.

`make integration-wayland` runs the external public API integration package
against the current compositor. It requires `WAYLAND_DISPLAY` and sets
`SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1`.

`make test-graphics-preview-client` runs an external compile/test package for
the `WaylandGraphicsPreview` product. It does not require a live compositor or a
GPU-capable session.

`make gpu-preview-wayland` runs package-internal GPU preview checks against the
current compositor. It requires `WAYLAND_DISPLAY`, sets
`SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS=1`, and enables the GBM/EGL smoke path
with `SWL_RUN_GPU_SMOKE=1`. The current test path proves the linux-dmabuf
capability gate and a local GBM/EGL clear plus dmabuf export when an accessible
DRM render node is present. Future compositor import and presentation checks can
attach to the same command.

The command runs `./scripts/smoke/gpu-preview-wayland.sh`.

`make wayland-headless` starts headless Weston through
`scripts/smoke/with-headless-weston.sh`, then runs both smoke and public
integration tests against that private compositor.

`make wayland-request-headless` starts headless Weston and runs the env-gated
window-control and source-side drag request-path tests against that private
compositor. It sets `SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1` and
`SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS=1`.

`make wayland-request-headless-tsan` runs the same focused request-path tests
under ThreadSanitizer. `make wayland-request-headless-asan` runs them under
AddressSanitizer with LeakSanitizer disabled by default. These jobs are focused
on request wrapper ordering and descriptor/request lifecycles; GPU hardware
paths remain separate. The request-path runner defaults to a 600 second timeout
because sanitizer builds can spend several minutes compiling before tests start.
Override it with `SWIFT_WAYLAND_REQUEST_PROCESS_TIMEOUT_SECONDS`.

`make gpu-preview-headless` starts headless Weston, then runs the GPU preview
capability and GBM/EGL smoke path against that private compositor.

`make check` runs the normal local check set. It runs the live Wayland smoke
check only when `WAYLAND_DISPLAY` is already set.

`make release-check` runs the base check set first. After that, it uses the
current compositor when `WAYLAND_DISPLAY` is set, uses headless Weston when
`weston` is installed, and fails in CI or when `REQUIRE_WAYLAND_SMOKE=1` if no
live Wayland path is available.

`make swiftbuild-smoke` runs an informational Swift Build preview check. Native
SwiftPM remains the supported build system; the smoke reports unsupported
toolchains and Swiftly layout issues without treating those as package
correctness failures.

`scripts/ci/repeat-test.sh` repeats one filtered test suite for local stress
validation. Use it for concurrency-sensitive suites before promoting a
scheduler, event-loop, or descriptor-lifecycle change.

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
  clang git make ripgrep pkg-config \
  libdrm-dev libegl-dev libgbm-dev libgles-dev \
  libwayland-dev libxkbcommon-dev \
  wayland-protocols \
  weston
```

Fedora/RHEL-like:

```bash
sudo dnf install \
  clang git make ripgrep \
  pkgconf-pkg-config \
  libdrm-devel mesa-libEGL-devel mesa-libgbm-devel mesa-libGLES-devel \
  wayland-devel wayland-protocols-devel \
  libxkbcommon-devel \
  weston
```

openSUSE:

```bash
sudo zypper --non-interactive install \
  clang git make ripgrep \
  pkgconf-pkg-config \
  libdrm-devel Mesa-libEGL-devel libgbm-devel Mesa-libGLESv2-devel \
  wayland-devel wayland-protocols-devel \
  libxkbcommon-devel \
  weston
```

Swift 6.3.2 SwiftPM may also need a compatibility `libxml2.so.2` on
openSUSE. The project Swift wrappers load `$SWIFT_COMPAT_LIBS` when present,
defaulting to `$HOME/.local/share/swift-compat-libs`; direct toolchain calls
must expose that directory through `LD_LIBRARY_PATH` or another runtime loader
path.

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
