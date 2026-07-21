# Linux Live Wayland Testing

Live tests use either the caller's `WAYLAND_DISPLAY` or a private headless Weston
socket. Use a desktop session for compositor-specific behavior and headless
Weston for noninteractive request paths.

## Commands

| Command | Coverage |
| --- | --- |
| `swift run wck smoke live` | Connects, configures a toplevel, commits SHM, and checks the frame callback. |
| `swift run wck smoke integration` | Runs the external public API client against the current compositor. |
| `swift run wck smoke gpu-preview` | Reports graphics capabilities, fallback, and the managed GBM/EGL probe. |
| `swift run GraphicsPreviewExternalBufferSmoke -- --internal-test-buffer` | Submits and releases a renderer-owned dmabuf. |
| `swift run GraphicsPreviewExternalBufferSmoke -- --internal-test-buffer --stress-frames 120` | Cycles three external-buffer registrations. |
| `swift run wck smoke headless -- wck smoke live` | Runs the SHM smoke against private Weston. |
| `swift run wck smoke headless -- wck smoke integration` | Runs public request paths against private Weston. |
| `swift run wck smoke headless -- wck smoke gpu-preview` | Runs graphics capability and fallback checks against private Weston. |
| `swift run wck test integration-graphics-preview` | Builds and tests the external graphics-preview package without a compositor. |

`smoke integration` sets
`WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS=1`. The headless integration
command also enables window-control and source-side drag request tests.

`smoke gpu-preview` sets
`WAYLAND_CLIENT_KIT_ENABLE_GPU_PREVIEW_TESTS=1` and `WCK_RUN_GPU_SMOKE=1`. It
prints a `WaylandClientKit GPU Preview Runtime Path` block for
[Compositor Matrix](compositor-matrix.md). Render-node-dependent work reports an
environment skip when no DRM render node is accessible.

The external-buffer smoke uses package-internal GBM/EGL code only to allocate
its test image. A passing result covers import, submission, compositor release,
and registration reuse; it does not expose that allocator as public API.

## Headless Weston Contract

The headless wrapper:

- creates private `XDG_RUNTIME_DIR`, `XDG_CONFIG_HOME`, and socket values
- unsets inherited `WAYLAND_SOCKET`
- starts Weston with `--backend=headless-backend.so`
- waits for the socket before running the child command
- captures logs, terminates Weston, and removes the temporary runtime directory

Weston logs are printed when the child command fails.

Headless request-path coverage can be collected with:

```bash
WAYLAND_CLIENT_KIT_HEADLESS_COVERAGE=1 \
  swift run wck smoke headless -- wck test request-paths
swift run wck coverage summarize
```

Sanitizer variants are listed in [Release Checklist](release.md).

## Protocol Results

These globals are required for the baseline smoke:

- `wl_compositor`
- `wl_shm`
- `xdg_wm_base`

An optional-protocol test skips when the compositor does not advertise its
interface. The message must name that interface, for example:

```text
Skipping presentation-time live test: compositor did not advertise wp_presentation.
```

An advertised protocol that fails its request or callback path is a test
failure, not a skip.

## Recording Evidence

Record desktop and headless results in
[Compositor Matrix](compositor-matrix.md). Keep unit-test results separate from
live compositor evidence. After editing the matrix, run:

```bash
swift run wck compositor evidence-summary
```

Capture the compositor version, advertised interfaces, exact commands, runtime
path, fallback reason, and any required manual interaction.

System packages are listed in [Linux Dependencies](linux-dependencies.md).
Headless tests also require Weston.
