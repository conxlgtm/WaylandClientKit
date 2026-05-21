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

`make gpu-preview-wayland` prints a `SwiftWayland GPU Preview Runtime Path`
block. Paste that block into the Graphics Preview Evidence table before
summarizing the result in the main matrix.

## Matrix

| Compositor | Version | Protocol facts | Smoke | Public integration | GPU preview | Notes |
| ---------- | ------- | -------------- | ----- | ------------------ | ----------- | ----- |
| Weston headless | pending | pending | pending | pending | pending | CI and local repeatability target. |
| GNOME / Mutter | pending | pending | pending | pending | pending | Real desktop target. |
| KDE / KWin | pending | pending | pending | pending | pending | Real desktop target. |
| Sway / wlroots | pending | pending | pending | pending | pending | wlroots target. |

## Graphics Preview Evidence

Each row should come from the pasteable GPU preview runtime-path report plus
the raw protocol facts collected under the same compositor session.

| Compositor | Display | Globals | dmabuf | GBM | EGL | explicit sync | FIFO | commit timing | metadata | presentation feedback | backing | failure/fallback |
| ---------- | ------- | ------- | ------ | --- | --- | ------------- | ---- | ------------- | -------- | --------------------- | ------- | ---------------- |
| Weston headless | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| GNOME / Mutter | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| KDE / KWin | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Sway / wlroots | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |

Record graphics facts in this form:

```text
SwiftWayland GPU Preview Runtime Path
display: <WAYLAND_DISPLAY>
compositor: <name/version or unknown>
window: <created/submitted/fallback>
dmabuf: <advertised vN/unavailable>, runtime <status>
gbm: <status>
egl: <status>
explicit-sync: <advertised vN/unavailable>, runtime <status>
pacing: fifo <status>, commit-timing <status>
metadata: content-type <status>, alpha-modifier <status>, tearing-control <status>, color-representation <status>, color-management <status>
presentation: <status>
backing: <gpu/software fallback(reason)/unavailable(reason)>
```

The `Globals` column should include exact interface names for missing optional
protocols. If a protocol is advertised but object creation or request use
fails, record that as a failure for that protocol rather than as a skip.

## Protocols To Record

- `wl_compositor`
- `wl_shm`
- `wl_seat`
- `xdg_wm_base`
- `wp_viewporter`
- `wp_fractional_scale_manager_v1`
- `wp_presentation`
- `zwp_linux_dmabuf_v1`
- `wp_linux_drm_syncobj_manager_v1`
- `wp_fifo_manager_v1`
- `wp_commit_timing_manager_v1`
- `wp_content_type_manager_v1`
- `wp_alpha_modifier_v1`
- `wp_tearing_control_manager_v1`
- `wp_color_representation_manager_v1`
- `wp_color_manager_v1`
- `wl_data_device_manager`
- `zwp_primary_selection_device_manager_v1`
- `wp_cursor_shape_manager_v1`
- `zwp_text_input_manager_v3`
- `zxdg_decoration_manager_v1`
- `zxdg_output_manager_v1`

## Runtime Facts

Smoke and GPU-preview notes should use these terms when available:

- `syncobj`: `unavailable`, `advertised`, `configured`, `active`, or
  `fallback(<reason>)`
- `fifo`: `unavailable`, `advertised`, or `active`
- `commitTiming`: `unavailable`, `advertised`, `configured`, or `active`
- `dmabuf`, `gbm`, `egl`: `unavailable`, `advertised`, `configured`, `active`,
  or `failed(<reason>)`
- `presentationFeedback`: `unavailable`, `available`, `requested`, or
  `observed`
- `contentType`, `alphaModifier`, `tearingControl`,
  `colorRepresentation`, and `colorManagement`: `unavailable`, `advertised`,
  `configured`, or `failed(<reason>)`
- `backing`: `gpu`, `shm`, `fallback(<reason>)`, or `unavailable(<reason>)`
- `surface`: `scale=<value>` and `outputs=<count>`

The preview graphics API uses the same vocabulary for public projected runtime
paths. A projection can say that dmabuf is advertised or unavailable, but only
live smoke and GPU-preview checks can prove configured or active GPU resources.

## Result Terms

- `pass`: the check ran and succeeded.
- `skip: <protocol>`: the compositor did not advertise an optional protocol.
- `fail: <reason>`: an advertised path failed or the compositor disconnected.
- `not run`: no evidence was collected for that cell.
