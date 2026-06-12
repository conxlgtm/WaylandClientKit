# Foundation Evidence Report

This report summarizes the current foundation-candidate evidence. The detailed
rows live in [compositor-matrix.md](compositor-matrix.md), and the readiness
checklist lives in
[foundation-candidate-status.md](foundation-candidate-status.md).

Status: SwiftWayland is not yet a foundation release candidate.

Decision after this pass: B. SwiftWayland needs one more hardening and evidence
sprint before framework work.

## Final Evidence Pass: 2026-06-09, GNOME Addendum: 2026-06-11

Raw command output for this pass was collected locally under
`evidence/2026-06-09/`. The GNOME VM addendum was collected under
`evidence/2026-06-11/gnome/`. The raw logs are not committed; each matrix row
should be traceable to one of those command logs.

### Environments

- KDE/KWin: current desktop Wayland session on `wayland-0`; pass for live
  smoke, integration smoke, GPU preview smoke, examples build, managed GPU
  active submission, and bounded auto-close feature examples.
- Weston headless: repeatable headless Weston 15.0.0 path through `swl smoke
  headless`; pass for live, integration, and GPU preview smoke. This is not a
  desktop compatibility claim.
- Sway/wlroots: nested Sway session under KDE/Plasma on `wayland-1`; pass for
  live smoke, integration smoke, GPU preview smoke, and both graphics preview
  examples. Feature-specific manual/auto examples were not run inside nested
  Sway.
- GNOME/Mutter: Fedora GNOME Wayland VM on `wayland-0`; pass for live smoke,
  integration smoke, GPU preview smoke, `GPUPreviewSmokeClient`, and
  `GraphicsPreviewManagedGPUClear`. Managed GPU reported typed software
  fallback `surfaceFeedbackUnavailable`.

### KDE/KWin Protocol Facts

`wayland-info` reported:

- `zwp_linux_dmabuf_v1` v5
- `wp_linux_drm_syncobj_manager_v1` v1
- `wp_fifo_manager_v1` v1
- `wp_presentation` v2
- `zwp_text_input_manager_v3` v1
- `wp_cursor_shape_manager_v1` v2
- `zwp_pointer_constraints_v1` v1
- `zwp_relative_pointer_manager_v1` v1
- `xdg_toplevel_icon_manager_v1` v1
- `zwp_idle_inhibit_manager_v1` v1
- `xdg_system_bell_v1` v1
- `xdg_activation_v1` v1
- color metadata protocols advertised
- commit timing unavailable

### Sway/wlroots Protocol Facts

Nested Sway/wlroots reported:

- `zwp_linux_dmabuf_v1` v4
- `wp_linux_drm_syncobj_manager_v1` v1
- `wp_presentation` v2
- `zwp_text_input_manager_v3` v1
- `wp_cursor_shape_manager_v1` v1
- `zwp_pointer_constraints_v1` v1
- `zwp_relative_pointer_manager_v1` v1
- `zwp_idle_inhibit_manager_v1` v1
- `xdg_activation_v1` v1
- content type, alpha modifier, and tearing control advertised
- FIFO, color representation, color management, top-level icon, and system bell
  unavailable in this nested session

### GNOME/Mutter Protocol Facts

Fedora GNOME VM `wayland-info` reported:

- `zwp_linux_dmabuf_v1` v3
- `wp_presentation` v2
- `wp_fifo_manager_v1` v1
- `wp_commit_timing_manager_v1` v1
- `zwp_text_input_manager_v3` v1
- `wp_cursor_shape_manager_v1` v2
- `zwp_pointer_constraints_v1` v1
- `zwp_relative_pointer_manager_v1` v1
- `zwp_idle_inhibit_manager_v1` v1
- `xdg_system_bell_v1` v1
- `xdg_activation_v1` v1
- `wp_color_manager_v1` v2
- `wp_color_representation_manager_v1` v1
- `xdg_toplevel_drag_manager_v1` v1
- linux-drm-syncobj unavailable
- top-level icon unavailable

## Commands Run

Headless Weston:

- `nix develop -c swift run swl smoke headless -- swl smoke live`
- `nix develop -c swift run swl smoke headless -- swl smoke integration`
- `nix develop -c swift run swl smoke headless -- swl smoke gpu-preview`

KDE/KWin:

- `wayland-info`
- `swift run swl tools toolchain-smoke`
- `swift run swl examples build`
- `swift run swl smoke live`
- `swift run swl smoke integration`
- `swift run swl smoke gpu-preview`
- `swift run GPUPreviewSmokeClient`
- `swift run GraphicsPreviewManagedGPUClear`
- `swift run swl ci check`

`swift run swl ci check` was attempted on KDE/KWin, but the process remained
active after building `swl` with no child process and no further output for
several minutes. The evidence pass continued with the individual commands above.

Nested Sway/wlroots:

- `WLR_BACKENDS=wayland WLR_LIBINPUT_NO_DEVICES=1 sway -c /tmp/swiftwayland-sway/config`
- `wayland-info`
- `swift run swl smoke live`
- `swift run swl smoke integration`
- `swift run swl smoke gpu-preview`
- `swift run GPUPreviewSmokeClient`
- `swift run GraphicsPreviewManagedGPUClear`

GNOME/Mutter:

- `wayland-info`
- `swift run swl smoke live`
- `swift run swl smoke integration`
- `swift run swl smoke gpu-preview`
- `swift run GPUPreviewSmokeClient`
- `swift run GraphicsPreviewManagedGPUClear`

KDE/KWin bounded feature examples:

- `swift run SessionStateSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run SurfaceRegionSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run DamageRegionSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run SubsurfaceSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run CustomCursorSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run CursorPolicySmoke --auto-close --print-summary --duration-seconds 3`
- `swift run WindowIconSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run IdleInhibitSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run SystemBellSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run XDGActivationSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run PointerCaptureSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run TextInputSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run DataTransferSmoke --auto-close --print-summary --duration-seconds 3`
- `swift run PresentationFeedbackAnimation --auto-close --print-summary --duration-seconds 3`
- `swift run ClientSideResizeChrome --auto-close --print-summary --duration-seconds 3`
- `swift run SerialActionsProbe --auto-close --print-summary --duration-seconds 3`

Sanitizers:

- `swift run swl test tsan`
- `ASAN_OPTIONS=detect_leaks=0 swift run swl test asan`
- `ASAN_OPTIONS=detect_leaks=1 swift run swl test asan`
- `ASAN_OPTIONS=detect_leaks=1 swift test --sanitize=address --no-parallel --filter WaylandExampleSupportTests`

## GPU Evidence

KDE/KWin:

- Requested backing: managed GPU.
- Actual backing: managed GPU.
- dmabuf: advertised v5 and runtime active.
- Surface feedback: usable.
- Render node: active.
- GBM: active.
- EGL: configured.
- dmabuf import: active.
- Presentation feedback: advertised v1, runtime advertised, requested true.
- Submitted frame: success show, 192x192.
- Fallback reason: none.
- Failure: none.

Nested Sway/wlroots:

- Requested backing: managed GPU.
- Actual backing: managed GPU.
- dmabuf: advertised v4 and runtime active.
- Surface feedback: usable.
- Render node: active.
- GBM: active.
- EGL: configured.
- dmabuf import: active.
- Presentation feedback: advertised v1, runtime advertised, requested true.
- Submitted frame: success show, 96x96.
- Fallback reason: none.
- Failure: none.

Headless Weston:

- Requested backing: managed GPU.
- Actual backing: software fallback.
- Fallback reason: `dmabufUnavailable`.
- Active GPU is not expected in this environment because dmabuf is unavailable.

GNOME/Mutter:

- Requested backing: managed GPU.
- Actual backing: software fallback.
- Fallback reason: `surfaceFeedbackUnavailable`.
- `GPUPreviewSmokeClient` reported `dmabuf advertised v3`, surface dmabuf
  feedback not configured, render node/GBM/EGL/dmabuf import/buffer lifecycle
  fallback `surfaceFeedbackUnavailable`, submitted frame `success show`, frame
  size `96x96`, release/reuse not observed, and failure `none`.
- `GraphicsPreviewManagedGPUClear` reported `dmabuf advertised v3`, surface
  feedback advertised but not configured, presentation feedback advertised v1,
  submitted frame result `fallback(surfaceFeedbackUnavailable)`, presentation
  feedback requested, and failure `none`.

## Manual Interaction Status

- Serial-sensitive actions: auto-close pass on KDE/KWin with
  `buttonPresses=0`. A 2026-06-11 manual run logged live `seat=seat-10`
  button serials, pointer locations, configure snapshots, 94 `move` attempts,
  6 `window-menu` attempts, and `threw=false` request results. Resize and
  drag-source serial paths were not observed and remain open.
- Pointer lock/confine: auto-close pass on KDE/KWin with relative pointer v1 and
  pointer constraints v1 available. A 2026-06-11 manual run logged
  `relative pointer auto-subscribed`, `lock requested id=locked-pointer-1`,
  `activated(locked-pointer-1)`, sustained `relative motion` events while the
  visible cursor was pinned, `inactivePersistent(locked-pointer-1)`, `result:
  pass`, and `cleanup: pass`. A second 2026-06-11 manual run logged
  `operation: confine-pointer pass`, `confine requested id=confined-pointer-1`,
  `activated(confined-pointer-1)`, 3108 `relative motion` events, a typed
  duplicate-request failure while a constraint was already active,
  `inactivePersistent(confined-pointer-1)`, `result: pass`, and `cleanup: pass`.
- Data-transfer drag source: auto-close pass on KDE/KWin with clipboard v3,
  drag v3, and primary v1 available. A 2026-06-11 manual rerun after the empty
  MIME callback fix logged clipboard/primary offer reads, private KDE MIME
  filtering, `operation: start-drag-source pass`, target/action negotiation to
  `text/plain;charset=utf-8` and `copy`, 165 drag-motion events, `drag dropped`,
  a 51-byte text/plain;charset=utf-8 read, `drag source drop performed`, `drag
  source finished ... action=copy`, `result: pass`, and `cleanup: pass`.
- Managed GPU resize: active managed GPU clear-frame submission passed on
  KDE/KWin and nested Sway; manual resize/reconfigure stress still not run.
- Surface role stress: `SubsurfaceSmoke` initially crashed on KDE/KWin with
  a frame-callback-not-ready error. The example was fixed to classify that
  typed condition as `blocked(frameCallbackOutstanding)`, request redraw, and exit
  cleanly. The rerun passed.

## Sanitizer Status

- TSan: pass, `swift run swl test tsan`.
- ASan with `detect_leaks=0`: pass, `ASAN_OPTIONS=detect_leaks=0 swift run swl
  test asan`.
- LSan: unusable(environment). With `ASAN_OPTIONS=detect_leaks=1`, SwiftPM test
  discovery terminated during `--dump-tests-json` and LeakSanitizer reported a
  fatal error with the hint that LeakSanitizer does not work under ptrace.

## Remaining Blockers

- Active managed GPU on GNOME/Mutter is still missing; the current VM evidence
  records typed fallback `surfaceFeedbackUnavailable`.
- Manual serial-sensitive actions need real button press evidence.
- Manual pointer lock/confine has KDE/KWin evidence; broaden to another
  desktop compositor if practical.
- Manual data-transfer drag-source/drop now has KDE/KWin evidence; broaden to
  another desktop compositor if practical.
- Managed GPU resize/reconfigure needs a manual or automated stress pass.
- `swift run swl ci check` needs investigation on the KDE host because it hung
  after building `swl`.

## Next Step

Stay on SwiftWayland for one more hardening and evidence sprint. The next
maintainer pass should run the manual interaction checklist on KDE/KWin and
GNOME/Mutter where practical, stress managed GPU resize/reconfigure, broaden
active/fallback/failure GPU evidence, and investigate the `swl ci check` hang
observed during this evidence pass.
