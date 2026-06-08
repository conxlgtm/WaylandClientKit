# Foundation Evidence Report

This report summarizes the current foundation-candidate evidence. The detailed
rows live in [compositor-matrix.md](compositor-matrix.md), and the readiness
checklist lives in
[foundation-candidate-status.md](foundation-candidate-status.md).

Status: SwiftWayland is not yet a foundation release candidate.

Decision after this pass: B. SwiftWayland needs one more hardening and evidence
sprint before framework work.

## Evidence Pass

Date: 2026-06-08

Host evidence:

- Nix development shell used Swift 6.3.2.
- KDE/KWin was available as a live desktop Wayland session on `wayland-0`.
- Headless Weston 15.0.0 was available through `swl smoke headless`.
- GNOME/Mutter was unavailable on this host.
- Sway/wlroots was unavailable in the Nix/dev shell on this host.

KDE/KWin protocol facts from `wayland-info`:

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

## Commands Run

- `swift --version`
- `nix develop -c swift --version`
- `nix develop -c swift run swl tools toolchain-smoke`
- `nix develop -c swift run swl ci check`
- `nix develop -c swift run swl ci release`
- `nix develop -c swift run swl examples build`
- `nix develop -c swift run swl smoke live`
- `nix develop -c swift run swl smoke integration`
- `nix develop -c swift run swl smoke gpu-preview`
- `nix develop -c swift run GPUPreviewSmokeClient`
- `nix develop -c swift run GraphicsPreviewManagedGPUClear`
- `wayland-info`
- `nix develop -c swift run swl smoke headless -- swl smoke live`
- `nix develop -c swift run swl smoke headless -- swl smoke integration`
- `nix develop -c swift run swl smoke headless -- swl smoke gpu-preview`

Feature smoke examples were run under KDE/KWin with `--auto-close
--print-summary --duration-seconds 1` where supported:

- `SurfaceRegionSmoke`
- `DamageRegionSmoke`
- `SubsurfaceSmoke`
- `CustomCursorSmoke`
- `CursorPolicySmoke`
- `WindowIconSmoke`
- `IdleInhibitSmoke`
- `SystemBellSmoke`
- `XDGActivationSmoke`
- `PointerCaptureSmoke`
- `TextInputSmoke`
- `DataTransferSmoke`
- `PresentationFeedbackAnimation`
- `ClientSideResizeChrome`
- `SerialActionsProbe`

The same feature target list passed through headless Weston. The headless
runner suppresses child output on success, so the matrix records the headless
loop as exit-status evidence rather than detailed per-target logs.

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
- Submitted frame: success show, 192x192.
- Fallback reason: none.
- Failure: none.

Headless Weston:

- Requested backing: managed GPU.
- Actual backing: software fallback.
- Fallback reason: `dmabufUnavailable`.
- Active GPU is not expected in this environment because dmabuf is unavailable.

GNOME/Mutter and Sway/wlroots:

- Environment skips in this pass. They remain foundation-readiness blockers.

## Runtime And Surface Evidence

KDE/KWin passed bounded smoke for:

- surface input and opaque regions
- partial damage
- subsurface creation, positioning, and desynchronized mode
- custom cursor image, hidden cursor, and theme cursor transitions
- window icon set, pixel icon set, and reset
- idle inhibit create and destroy
- system bell display and window requests
- xdg activation token and activation request
- text-input enable and disable
- data-transfer clipboard, drag, and primary-selection capability paths
- presentation feedback with observed presented frames
- client-side resize chrome auto-close cleanup
- serial-sensitive action probe event collection

Remaining live interaction gaps:

- Pointer lock and confine need manual motion proof beyond unattended
  capability and lifecycle smoke.
- Serial-sensitive move, resize, menu, and drag-source request paths need manual
  input proof under KDE/KWin.
- GNOME/Mutter and Sway/wlroots need current evidence rows.
- GPU resize and reconfiguration need broader live compositor stress evidence,
  even though the unit coverage protects geometry-sensitive buffer reuse.

## Current Blockers

- Broader compositor coverage is incomplete: GNOME/Mutter and Sway/wlroots were
  unavailable in this pass.
- Several serial-sensitive or pointer-capture paths still require manual input
  evidence under a desktop compositor.
- Sanitizer evidence remains environment-dependent and should be recorded when
  available.

## Next Step

Stay on SwiftWayland for one more hardening and evidence sprint. Do not start
framework work until the compositor matrix replaces environment skips and manual
interaction gaps with current pass, skip, or fail rows.
