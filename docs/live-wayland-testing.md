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
make gpu-preview-headless
make check
make release-check
```

`make smoke-wayland` runs the `swift-wayland-smoke` executable against the
current compositor. It requires `WAYLAND_DISPLAY`.

`make integration-wayland` runs the external public API integration package
against the current compositor. It requires `WAYLAND_DISPLAY` and sets
`SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1`.

`make gpu-preview-wayland` runs package-internal GPU preview live capability
tests against the current compositor. It requires `WAYLAND_DISPLAY` and sets
`SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS=1`. The current test path proves the
linux-dmabuf capability gate; future GPU allocation and presentation checks can
attach to the same command.

The command runs `./scripts/smoke/gpu-preview-wayland.sh`.

`make wayland-headless` starts headless Weston through
`scripts/smoke/with-headless-weston.sh`, then runs both smoke and public
integration tests against that private compositor.

`make gpu-preview-headless` starts headless Weston, then runs the GPU preview
capability gate against that private compositor.

`make check` runs the normal local check set. It runs the live Wayland smoke
check only when `WAYLAND_DISPLAY` is already set.

`make release-check` runs the base check set first. After that, it uses the
current compositor when `WAYLAND_DISPLAY` is set, uses headless Weston when
`weston` is installed, and fails in CI or when `REQUIRE_WAYLAND_SMOKE=1` if no
live Wayland path is available.

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
Skipping GPU preview live test: compositor did not advertise zwp_linux_dmabuf_v1.
```

Do not hide an advertised-but-broken protocol behind a skip. That is a client
or compositor behavior failure, and the test should report it as such.
