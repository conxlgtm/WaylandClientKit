# Compositor Matrix

SwiftWayland checkpoint notes should record compositor evidence separately from
unit tests. Headless Weston is the repeatable path, but it is not enough by
itself to claim desktop compatibility.

Use this matrix for development checkpoints and PR notes that touch live
Wayland behavior. Missing optional protocols should be recorded as skips with
the exact protocol name. Advertised-but-broken protocol paths should be recorded
as failures.

## Collection

Run these under the compositor being tested:

```bash
swift run swl smoke live
swift run swl smoke integration
swift run swl smoke gpu-preview
swift build
```

For headless Weston:

```bash
swift run swl smoke headless -- swl smoke integration
swift run swl smoke headless -- swl smoke gpu-preview
```

`swift run swl smoke gpu-preview` prints a `SwiftWayland GPU Preview Runtime Path`
block. Paste that block into the Graphics Preview Evidence table before
summarizing the result in the main matrix.

For an interactive checklist grouped by feature, run:

```bash
swift run ClientSideResizeChrome
swift run SerialActionsProbe
swift run TwoWindowFrameworkHost -- --auto-close --print-summary
swift run GPUPreviewSmokeClient
```

Smoke examples should print matrix-friendly lines such as `feature`,
`capability`, `operation`, `cleanup`, and `notes` where the feature is bounded
enough to summarize.

## Feature Categories

Record these feature categories for each compositor row when the relevant
example or manual probe has been run:

| Category | Evidence target |
| --- | --- |
| input region | `SurfaceRegionSmoke` pointer events inside/outside region |
| opaque region | `SurfaceRegionSmoke` set/reset logs |
| partial damage | `DamageRegionSmoke` logical and mapped damage logs |
| subsurface creation | `SubsurfaceSmoke` child creation and cleanup |
| subsurface positioning | `SubsurfaceSmoke` movement logs |
| subsurface sync/desync | `SubsurfaceSmoke` mode logs |
| custom cursor image | `CustomCursorSmoke` custom/hidden/theme transitions |
| cursor scale policy | `CursorPolicySmoke` focused-output cursor scale logs |
| window icon | `WindowIconSmoke` named, pixel, and reset operations |
| idle inhibit | `IdleInhibitSmoke` create and destroy operations |
| system bell | `SystemBellSmoke` display/window ring operations |
| activation | `XDGActivationSmoke` token request and activate request |
| pointer lock/confine | `PointerCaptureSmoke` lock/confine lifecycle |
| relative pointer | `PointerCaptureSmoke` relative motion events |
| text input | `TextInputSmoke` capability and commit summary |
| data transfer | `DataTransferSmoke` clipboard/primary/drag summary |
| presentation feedback | `PresentationFeedbackAnimation` feedback summary |
| graphics preview fallback/GPU path | `GPUPreviewSmokeClient` runtime-path report |

## Matrix

| Compositor | Version | Protocol facts | Smoke | Public integration | GPU preview | Notes |
| ---------- | ------- | -------------- | ----- | ------------------ | ----------- | ----- |
| Weston headless | pending | pending | pending | pending | pending | CI and local repeatability target. |
| GNOME / Mutter | Ubuntu/GNOME session, 2026-05-24 | facts script ran; globals unavailable because `wayland-info`/`weston-info` is not installed | bounded framework-facing examples ran | public import checks passed in framework handoff | pending | Real desktop target. |
| KDE / KWin | openSUSE Tumbleweed KDE/KWin, 2026-05-23 handoff | pending | framework handoff ran live probes | public import checks passed in framework handoff | software submission usable in handoff | Re-run data-transfer cleanup after the shutdown fixes. |
| Sway / wlroots | pending | pending | pending | pending | pending | wlroots target. |

## Framework Host Evidence

Use this table for framework-facing behavior that is not captured by generic
smoke tests. Record whether the evidence came from a bounded SwiftWayland
example, a manual example run, or an external framework harness.

| Compositor | Client-side resize chrome | Serial-sensitive resize/move/menu/drag | Pointer capture | Text input | Interpreted keyboard fallback | Clipboard/private MIME behavior | Drag-source behavior | Popup lifecycle | Presentation feedback | Cursor theme behavior | Graphics preview software fallback | Fatal cleanup/shutdown |
| ---------- | ------------------------- | -------------------------------------- | --------------- | ---------- | ----------------------------- | ------------------------------- | -------------------- | --------------- | --------------------- | --------------------- | ---------------------------------- | ---------------------- |
| GNOME / Mutter | SwiftWayland bounded two-window examples create and close both windows; manual `ClientSideResizeChrome` resize/close still needs a post-fix run. | `SerialActionsProbe` logs target, seat, serial, location, decoration mode, capabilities, snapshot, and thrown status. Earlier GNOME manual run logged requests but move/resize/menu did not visibly start. | `PointerCaptureSmoke` added; live lock/confine/relative-motion evidence pending. | `TextInputSmoke --auto-close --print-summary` reports text-input v1 available and zero commits without user typing. | External framework handoff observed ordinary text through interpreted keyboard events. | `DataTransferSmoke --auto-close --print-summary` reports clipboard v3, drag v3, and primary v1 available. Earlier GNOME handoff logged stale offers as controlled unknown-offer diagnostics. | Earlier GNOME full probe completed drag source, offer, drop, text read, and final copy action; KDE cleanup crash did not reproduce on GNOME. | Bounded two-window examples closed both windows without lifecycle callback crashes. | `PresentationFeedbackAnimation --duration-seconds 3 --print-summary` reports presentation feedback available; bounded unattended run observed no frames in that short run. | Cursor cleanup and focused-output scale policy have unit coverage; live `CursorPolicySmoke` still needs manual GNOME confirmation. | Pending current run; prior handoff reported graphics-preview software submission usable. | Fatal cleanup suppression has unit coverage; bounded GNOME examples close without display teardown crashes. |
| KDE / KWin | Handoff reported basic hosting, redraw, resize, cursor shape, and multi-window behavior usable. | Drag-source serial ordering was fixed in the framework before the crash repro; SwiftWayland serial examples need a KDE run. | `PointerCaptureSmoke` needs a KDE run. | Handoff reported text-input advertised but ordinary typing arrived through interpreted keyboard text more than text-input commits. | Handoff confirmed ordinary text through interpreted keyboard events. | Handoff observed KDE/private MIME types such as `application/x-kde-onlyReplaceEmpty`; framework should filter unknown/private MIME unless explicitly supported. | Handoff reproduced a right-click drag-source cleanup crash on the older path; current shutdown guard needs a KDE re-run. | Handoff reported popup creation/rendering usable; fatal popup cleanup now has unit coverage. | Handoff reported animation usable; current presentation example needs a KDE bounded run. | Handoff reported cursor shape usable; cursor theme shutdown order and scale policy now have unit coverage and need a KDE resize-close run. | Handoff reported graphics-preview software submission usable. | The old crash path was `DisplayCore.fail(_) -> surfaces.removeAll() -> TopLevelWindow.deinit -> close() -> onClosed`; current fatal cleanup tests cover callback suppression and store replacement. |
| Weston headless | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |
| Sway / wlroots | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending | pending |

## Diagonal Cursor Policy

Decision for this checkpoint: do not add public diagonal `PointerCursor` presets
yet. Keep theme-specific cursor names in examples and docs, with a known
fallback such as `.crosshair`, until the same names are verified across
GNOME/Mutter, KDE/KWin, Sway/wlroots, and Weston. Static custom cursor images
are available when an app or framework owns the pixels and hotspot.

Names to test:

- `nw-resize`
- `ne-resize`
- `sw-resize`
- `se-resize`
- `nwse-resize`
- `nesw-resize`

If multiple compositor/theme families resolve the same names consistently, add
public presets and update the public API baseline. If not, keep
`PointerCursor(name:)` plus fallback guidance as the public shape.

## Graphics Preview Evidence

Each row should come from the pasteable GPU preview runtime-path report plus
the raw protocol facts collected under the same compositor session.

Use these status terms for GPU path fields: `advertised`, `configured`,
`active`, `failed(<reason>)`, `fallback(<reason>)`, and `not tested`. Keep
registry advertisement separate from resource setup and frame submission.

| Compositor | Display | Globals | dmabuf | surface feedback | GBM | EGL | explicit sync | FIFO | commit timing | metadata | presentation feedback | submitted frame | release/reuse | backing | failure/fallback |
| ---------- | ------- | ------- | ------ | ---------------- | --- | --- | ------------- | ---- | ------------- | -------- | --------------------- | --------------- | ------------- | ------- | ---------------- |
| Weston headless | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested |
| GNOME / Mutter | wayland-0, ubuntu:GNOME / ubuntu, 2026-05-25 | dmabuf v5, explicit sync v1, FIFO, commit timing, presentation feedback v1, color management advertised, color representation pending | advertised | not configured | fallback(managedGPUSubmissionUnavailable) | fallback(managedGPUSubmissionUnavailable) | advertised | advertised | advertised | content type/alpha/tearing unavailable; color representation pending; color management advertised | advertised | success show, 96x96 | not observed, software fallback | software fallback(managedGPUSubmissionUnavailable) | none; `GraphicsPreviewManagedGPUClear` also closed cleanly with fallback(managedGPUSubmissionUnavailable) |
| KDE / KWin | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested |
| Sway / wlroots | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested | not tested |

Record graphics facts in this form:

```text
SwiftWayland GPU Preview Runtime Path
display: <WAYLAND_DISPLAY>
compositor: <name/version or unknown>
window creation: <success/failure>
dmabuf advertised version: <advertised vN/unavailable/pending>
surface dmabuf feedback: <usable/not configured/fallback/failed>
selected device: <selected/not selected/fallback/failed>
selected format/modifier: <selected/not selected/fallback/failed>
gbm device: <status>
gbm buffer allocation: <status>
egl display/context: <status>
egl clear/render: <status>
dmabuf import: <status>
explicit sync: <advertised vN/unavailable>, runtime <status>
fifo: <status>
commit timing: <status>
metadata content type: <status>
metadata alpha modifier: <status>
metadata tearing control: <status>
metadata color representation: <status>
metadata color management: <status>
presentation feedback: <status>
submitted frame: <success/failure>
frame size: <pixels>
release/reuse: <status>
backing: <gpu/software fallback(reason)/unavailable(reason)>
fallback reason: <reason/none>
failure: <error/none>
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
- `xdg_activation_v1`
- `xdg_toplevel_icon_manager_v1`
- `zwp_idle_inhibit_manager_v1`
- `xdg_system_bell_v1`
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
- `zwp_relative_pointer_manager_v1`
- `zwp_pointer_constraints_v1`
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
