# Compositor Matrix

SwiftWayland checkpoint notes should record compositor evidence separately from
unit tests. Headless Weston is the repeatable path, but it is not enough by
itself to claim desktop compatibility.

Use this matrix for development checkpoints and PR notes that touch live
Wayland behavior. Missing optional protocols should be recorded as skips with
the exact protocol name. Advertised-but-broken protocol paths should be recorded
as failures.

## Collection

Run this under the compositor being tested:

```bash
./scripts/smoke/collect-compositor-facts.sh
```

Then run the relevant checks:

```bash
make smoke-wayland
make integration-wayland
make gpu-preview-wayland
```

For headless Weston:

```bash
make wayland-headless
make gpu-preview-headless
```

Use `--include-smoke` when collecting facts if you also want the script to run
the noninteractive smoke executable:

```bash
./scripts/smoke/collect-compositor-facts.sh --include-smoke
```

## Matrix

| Compositor | Version | Protocol facts | Smoke | Public integration | GPU preview | Notes |
| ---------- | ------- | -------------- | ----- | ------------------ | ----------- | ----- |
| Weston headless | pending | pending | pending | pending | pending | CI and local repeatability target. |
| GNOME / Mutter | pending | pending | pending | pending | pending | Real desktop target. |
| KDE / KWin | pending | pending | pending | pending | pending | Real desktop target. |
| Sway / wlroots | pending | pending | pending | pending | pending | wlroots target. |

## Protocols To Record

- `wl_compositor`
- `wl_shm`
- `wl_seat`
- `xdg_wm_base`
- `wp_viewporter`
- `wp_fractional_scale_manager_v1`
- `wp_presentation`
- `zwp_linux_dmabuf_v1`
- `wl_data_device_manager`
- `zwp_primary_selection_device_manager_v1`
- `zxdg_decoration_manager_v1`
- `zxdg_output_manager_v1`

## Result Terms

- `pass`: the check ran and succeeded.
- `skip: <protocol>`: the compositor did not advertise an optional protocol.
- `fail: <reason>`: an advertised path failed or the compositor disconnected.
- `not run`: no evidence was collected for that cell.
