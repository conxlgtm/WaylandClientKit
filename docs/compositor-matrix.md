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
swift run swl compositor evidence-summary
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
| Weston headless | Weston 15.0.0 headless backend, 2026-06-09 | dmabuf unavailable, explicit sync unavailable, FIFO and presentation feedback advertised, content type and color metadata unavailable | `swift run swl smoke headless -- swl smoke live`, `swl smoke integration`, and `swl smoke gpu-preview` passed | Headless integration smoke passed | GPU preview smoke passed with software fallback `dmabufUnavailable` | Repeatable headless evidence target. This is not full desktop compatibility and active GPU is not expected without dmabuf. |
| GNOME / Mutter | Fedora GNOME Wayland VM on `wayland-0`, 2026-06-11 | `wayland-info`: dmabuf v3, presentation v2, FIFO v1, commit timing v1, text-input v3 v1, cursor-shape v2, pointer constraints v1, relative pointer v1, idle inhibit v1, system bell v1, xdg activation v1, color management v2, color representation v1, linux-drm-syncobj unavailable, top-level icon unavailable | `swift run swl smoke live`, `swift run swl smoke integration`, and `swift run swl smoke gpu-preview` passed | GNOME VM integration smoke passed after Fedora Swift index-store/toolchain fixes | `GPUPreviewSmokeClient` and `GraphicsPreviewManagedGPUClear` reported software fallback `surfaceFeedbackUnavailable` | Real GNOME/Mutter desktop-family evidence. Active GPU was not proven because surface dmabuf feedback was unavailable to the managed GPU path. |
| KDE / KWin | KDE / plasma session, 2026-06-09 plus manual pointer/serial addendum on 2026-06-11 | `wayland-info`: dmabuf v5, linux-drm-syncobj v1, FIFO v1, presentation v2, text-input v3 v1, cursor-shape v2, pointer constraints v1, relative pointer v1, top-level icon v1, idle inhibit v1, system bell v1, xdg activation v1, color metadata advertised, commit timing unavailable | `swift run swl smoke live`, `swift run swl smoke integration`, `swift run swl smoke gpu-preview`, and individual auto-close feature examples passed | live integration smoke passed; `swift run swl ci check` was attempted but hung after building `swl` with no child process/output | `GPUPreviewSmokeClient` and `GraphicsPreviewManagedGPUClear` reported active managed GPU submission | Active GPU presentation proven for clear-frame submission on this run. Manual pointer lock/confine with relative motion is proven. Manual serial move/window-menu requests are proven; serial resize/drag-source, data-transfer drag-source, and GPU resize remain unproven. |
| Sway / wlroots | nested Sway/wlroots under KDE/Plasma, 2026-06-09 | `wayland-info`: dmabuf v4, linux-drm-syncobj v1, presentation v2, text-input v3 v1, cursor-shape v1, pointer constraints v1, relative pointer v1, idle inhibit v1, xdg activation v1, content type/alpha/tearing metadata advertised, FIFO/color management/color representation/top-level icon/system bell unavailable | `swift run swl smoke live`, `swift run swl smoke integration`, and `swift run swl smoke gpu-preview` passed inside nested Sway | nested integration smoke passed | `GPUPreviewSmokeClient` and `GraphicsPreviewManagedGPUClear` reported active managed GPU submission | Nested wlroots evidence. Active GPU clear-frame submission was proven at 96x96; full bare-metal Sway evidence is still desirable. |

KDE/KWin manual interaction addendum on 2026-06-11:
`swift run PointerCaptureSmoke` passed manual pointer-lock, pointer-confine, and
relative-motion proof across two runs. The lock run logged `relative pointer
auto-subscribed`, `lock requested id=locked-pointer-1 seat=seat-10`,
`activated(locked-pointer-1)`, sustained `relative motion` events,
`inactivePersistent(locked-pointer-1)`, `result: pass`, and `cleanup: pass`.
The visible cursor pinned inside the window during lock, which is expected
compositor behavior for pointer lock while relative motion events continue.
The confine run logged `operation: confine-pointer pass`, `confine requested
id=confined-pointer-1 seat=seat-10`, `activated(confined-pointer-1)`, 3108
`relative motion` events, a typed duplicate-request failure while a constraint
was already active, `inactivePersistent(confined-pointer-1)`, `result: pass`,
and `cleanup: pass`.

`swift run SerialActionsProbe` passed a manual subset for live button serials.
The run logged live `seat=seat-10` pointer serials, 94 `action=move` attempts,
6 `action=window-menu` attempts, pointer locations, configure snapshots, and
`threw=false` request results. It did not log `action=resize` or `action=drag`,
so serial resize and drag-source serial proof remain open.

## Session Management Protocol Watch

SwiftWayland supports local framework-owned state through public restoration
snapshots and `SessionStateSmoke`. Compositor session-management protocol API is
deferred until protocol evidence is strong enough to keep the public boundary
honest.

KDE/KWin live session evidence on 2026-06-09:
`SessionStateSmoke --auto-close --print-summary --duration-seconds 3` passed.
The run captured title, app ID, logical geometry, scale, and output membership,
wrote state under `$XDG_STATE_HOME`, captured a final restoration snapshot
before exit, and closed with `remainingWindows=0`.

| Protocol | Upstream phase | Vendored XML | Public API | Evidence needed before API |
| -------- | -------------- | ------------ | ---------- | -------------------------- |
| `xx_session_manager_v1` or promoted successor | experimental or staging as upstream evolves | not vendored | deferred | compositor advertisement rows, smoke behavior, and a framework usage shape that does not confuse compositor session events with local scene restoration |

## Framework Host Evidence

Use this table for framework-facing behavior that is not captured by generic
smoke tests. Record whether the evidence came from a bounded SwiftWayland
example, a manual example run, or an external framework harness.

| Compositor | Client-side resize chrome | Serial-sensitive resize/move/menu/drag | Pointer capture | Text input | Interpreted keyboard fallback | Clipboard/private MIME behavior | Drag-source behavior | Popup lifecycle | Presentation feedback | Cursor theme behavior | Graphics preview software fallback | Fatal cleanup/shutdown |
| ---------- | ------------------------- | -------------------------------------- | --------------- | ---------- | ----------------------------- | ------------------------------- | -------------------- | --------------- | --------------------- | --------------------- | ---------------------------------- | ---------------------- |
| GNOME / Mutter | not run(feature-specific manual/auto example not run in GNOME VM) | not run(feature-specific manual example not run in GNOME VM) | not run(feature-specific manual/auto example not run in GNOME VM) | not run(`zwp_text_input_manager_v3` v1 advertised, feature example not run in GNOME VM) | not run(feature-specific keyboard input example not run in GNOME VM) | not run(`wl_data_device_manager` v3 and primary selection v1 advertised, feature example not run in GNOME VM) | not run(`xdg_toplevel_drag_manager_v1` v1 advertised, feature example not run in GNOME VM) | not run(feature-specific popup example not run in GNOME VM) | not run(`wp_presentation` v2 advertised, feature example not run in GNOME VM) | not run(cursor-shape v2 advertised, feature example not run in GNOME VM) | GPU preview fallback `surfaceFeedbackUnavailable` | GNOME live, integration, and GPU preview smoke exited 0 after Fedora Swift toolchain fixes. |
| KDE / KWin | auto pass(`ClientSideResizeChrome --auto-close --print-summary --duration-seconds 3`, `remainingWindows=0`); manual not run(edge hover/drag resize needs trusted pointer input) | auto pass(`SerialActionsProbe --auto-close --print-summary --duration-seconds 3`, `buttonPresses=0`); manual partial pass(2026-06-11 live `seat=seat-10` button serials selected `move` and `window-menu`, logged locations/snapshots/results, and all request results were `threw=false`; resize and drag-source actions not observed) | auto pass(`PointerCaptureSmoke --auto-close --print-summary --duration-seconds 3`, relative pointer v1 and constraints v1 available); manual pass(2026-06-11 auto-subscribed relative pointer, lock request activated `locked-pointer-1`, confine request activated `confined-pointer-1`, sustained relative motion logged, duplicate constraint request returned typed failure while active, inactive persistent cleanup, result pass) | auto pass(`TextInputSmoke --auto-close --print-summary --duration-seconds 3`, text-input v1 available, enable/disable clean, commits=0) | auto pass(keyboard fallback path present, no typed text entered) | auto pass(`DataTransferSmoke --auto-close --print-summary --duration-seconds 3`, clipboard v3, drag v3, primary v1, events=0, sources=0) | auto pass(drag-source capability advertised and cleanup clean); manual not run(source request/drop needs trusted pointer serial and target app) | Bounded examples closed without lifecycle callback crashes; popup-specific manual probe still not run | auto pass(`PresentationFeedbackAnimation --auto-close --print-summary --duration-seconds 3`, capability v2, frames=0, presented=0, discarded=0) | auto pass(`CursorPolicySmoke` cursor-shape v2 and `CustomCursorSmoke` custom image set); hidden/theme/manual pointer transitions still need visual confirmation | Active managed GPU clear-frame submission in both graphics preview examples; manual GPU resize/reconfigure not run | Auto-close feature examples exited cleanly after the subsurface example was fixed to report `blocked(frameCallbackOutstanding)` instead of crashing; 2026-06-11 pointer-lock/confine manual closes cleaned up. |
| Weston headless | Headless live/integration/gpu-preview smoke exited 0 | Headless smoke exited 0; manual interaction not possible in headless compositor | Headless smoke exited 0; manual lock/confine motion not possible in headless compositor | Headless smoke exited 0 | Headless smoke exited 0 where generated input is available | Headless smoke exited 0 | Headless smoke exited 0; drag-source/drop path needs desktop interaction | Headless smoke and integration closed cleanly | Headless smoke exited 0 | Headless smoke exited 0 | GPU preview fallback `dmabufUnavailable` | Headless live, integration, and GPU preview exited 0. |
| Sway / wlroots | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | nested smoke and integration exited 0 | not run(feature-specific manual/auto examples not run inside nested Sway) | not run(feature-specific manual/auto examples not run inside nested Sway) | Active managed GPU clear-frame submission in both graphics preview examples inside nested Sway | Nested Sway launched with `WLR_BACKENDS=wayland`; smoke live/integration/gpu-preview and GPU examples exited 0. |

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
`active`, `failed(<reason>)`, `fallback(<reason>)`, `unavailable(<protocol>)`,
and `environment skip(<reason>)`. Keep registry advertisement separate from
resource setup and frame submission.

| Compositor | Display | Globals | dmabuf | surface feedback | GBM | EGL | explicit sync | FIFO | commit timing | metadata | presentation feedback | submitted frame | release/reuse | backing | failure/fallback |
| ---------- | ------- | ------- | ------ | ---------------- | --- | --- | ------------- | ---- | ------------- | -------- | --------------------- | --------------- | ------------- | ------- | ---------------- |
| Weston headless | headless socket, Weston 15.0.0, 2026-06-09 | dmabuf unavailable, explicit sync unavailable, FIFO and presentation feedback advertised, content type and color metadata unavailable | unavailable(zwp_linux_dmabuf_v1) | fallback(dmabufUnavailable) | fallback(dmabufUnavailable) | fallback(dmabufUnavailable) | unavailable(wp_linux_drm_syncobj_manager_v1) | advertised | advertised | mixed unavailable/advertised | advertised | success show | software fallback | software fallback(dmabufUnavailable) | failure none, fallback dmabufUnavailable, active GPU not expected |
| GNOME / Mutter | wayland-0, Fedora GNOME Wayland VM, 2026-06-11 | dmabuf v3, presentation v2, FIFO v1, commit timing v1, text-input v3 v1, cursor-shape v2, pointer constraints v1, relative pointer v1, idle inhibit v1, system bell v1, xdg activation v1, color management v2, color representation v1, linux-drm-syncobj unavailable | advertised v3 | fallback(surfaceFeedbackUnavailable) | fallback(surfaceFeedbackUnavailable) | fallback(surfaceFeedbackUnavailable) | unavailable(wp_linux_drm_syncobj_manager_v1) | advertised | advertised | mixed unavailable/advertised | advertised v1, runtime advertised | success show, 96x96 | not observed, software fallback | software fallback(surfaceFeedbackUnavailable) | failure none, fallback surfaceFeedbackUnavailable, active GPU not proven |
| KDE / KWin | wayland-0, KDE / plasma, 2026-06-09 | dmabuf v5, linux-drm-syncobj v1, FIFO v1, presentation v2, content type, alpha, tearing, color representation, color management advertised, commit timing unavailable | advertised v5, runtime active | usable | active | configured | advertised v1, runtime advertised | advertised | unavailable | advertised | advertised v1, runtime advertised | success show, 192x192 | managed by GPU buffer lifecycle | gpu active / managedGPU | failure none, fallback none, active GPU proven |
| Sway / wlroots | wayland-1, nested Sway/wlroots under KDE/Plasma, 2026-06-09 | dmabuf v4, linux-drm-syncobj v1, presentation v2, content type, alpha, tearing advertised, FIFO unavailable, color representation unavailable, color management unavailable | advertised v4, runtime active | usable | active | configured | advertised v1, runtime advertised | unavailable | unavailable | mixed advertised/unavailable | advertised v1, runtime advertised | success show, 96x96 | managed by GPU buffer lifecycle | gpu active / managedGPU | failure none, fallback none, active GPU proven in nested session |

Record graphics facts in this form:

```text
SwiftWayland GPU Preview Runtime Path
display: <WAYLAND_DISPLAY>
compositor: <name/version or unknown>
window creation: <success/failure>
dmabuf advertised version: <advertised vN/unavailable/unknown>
surface dmabuf feedback: <usable/not configured/fallback/failed>
selected device: <selected/not selected/fallback/failed>
selected format/modifier: <selected/not selected/fallback/failed>
gbm device: <status>
gbm buffer allocation: <status>
egl display/context: <status>
egl clear/render: <status>
dmabuf import: <status>
buffer lifecycle: <status>
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
- `environment skip(<reason>)`: the compositor or hardware environment was not
  available for this evidence pass.
- `manual interaction required(<reason>)`: the unattended smoke path ran, but a
  human interaction path still needs proof.
- `manual not run(<reason>)`: the manual path was not exercised in this pass.
- `manual pass(<details>)`: a human interaction path ran and stayed healthy.
- `manual caveat(<details>)`: SwiftWayland made the request from live input and
  stayed healthy, but visible compositor behavior was absent or compositor-specific.
- `manual fail(<details>)`: the human interaction path crashed, disconnected, used
  stale input, or produced an untyped failure.
- `fail: <reason>`: an advertised path failed or the compositor disconnected.
- `not run`: no evidence was collected for that cell.
