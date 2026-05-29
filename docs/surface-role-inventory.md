# Surface Role Inventory

SwiftWayland has one internal surface substrate, `SurfaceRuntime`, and several
Wayland surface roles that use only the parts of that substrate that are valid
for the role. This document records the current role boundaries so future
features do not accidentally apply window-only operations to cursor or drag icon
surfaces.

## Role capability summary

| Role | Runtime | Damage | Input region | Opaque region | Metadata | Submit constraints |
| --- | --- | --- | --- | --- | --- | --- |
| `TopLevelWindow` | `SurfaceRuntime<TopLevelWindowRoleResources>` | public `show(damage:)` and `redraw(damage:)` | public | public | internal commit metadata | internal submit constraints |
| `PopupRoleSurface` | `SurfaceRuntime<PopupRoleResources>` | package presentation path | public | public | internal commit metadata | internal submit constraints |
| `CursorRoleSurface` | `SurfaceRuntime<CursorRoleResources>` | full cursor buffer damage only | unsupported | unsupported | unsupported | unsupported |
| `DragIconRoleSurface` | `SurfaceRuntime<DragIconRoleResources>` | full icon buffer damage only | unsupported | unsupported | unsupported | unsupported |
| graphics preview backing | managed window `SurfaceRuntime` path | forwarded software damage | window-owned | window-owned | preview metadata bridge | preview policy bridge |
| `SubsurfaceRoleSurface` | `SurfaceRuntime<SubsurfaceRoleResources>` | public software `show` and `redraw` | public | public | internal commit metadata | internal submit constraints |

`SurfaceRoleReadinessSnapshot` mirrors this table in package-internal state and
tests. The snapshot is not a public capability API; it is a guardrail for
internal role routing.

## Top-level windows

- Raw `wl_surface` owner: `TopLevelWindow`.
- Role object: xdg-surface and xdg-toplevel resources.
- Scale behavior: `SurfaceScaleInstallation` handles integer and fractional
  scale, viewport destination, and logical-to-buffer mapping.
- Output membership: tracked by `SurfaceRuntime` and reported through window
  events and cursor scale policy.
- Damage behavior: public logical `SurfaceDamageRegion` is validated, clipped,
  and mapped before commit. The first buffer-backed commit is full-frame damage.
- Input and opaque regions: public `Window.setInputRegion(_:)` and
  `Window.setOpaqueRegion(_:)` create one-shot `wl_region` objects and commit.
- Metadata behavior: package-internal surface commit metadata is validated
  against surface capabilities before commit.
- Submit constraints: package-internal synchronization and pacing constraints
  are capability-checked before commit.
- Destroy order: role resources are removed before the raw surface is destroyed.
- Late callback policy: frame and presentation callbacks are routed through the
  transaction and event hubs; discarded surfaces suppress lifecycle callbacks.

## Popups

- Raw `wl_surface` owner: `PopupRoleSurface`.
- Role object: xdg-surface and xdg-popup resources.
- Scale behavior: same `SurfaceRuntime` scale substrate as windows.
- Output membership: inherited through the surface runtime and display graph.
- Damage behavior: package presentation path uses the shared surface commit
  machinery.
- Input and opaque regions: public `PopupSurface` region APIs use the same
  applicator path as windows.
- Metadata behavior: available through the shared commit path when used
  internally.
- Submit constraints: available through the shared commit path when used
  internally.
- Destroy order: popup role is destroyed top-down according to the surface graph
  before the raw surface is released.
- Late callback policy: compositor dismissals mark popups closing and suppress
  duplicate lifecycle emission.

## Cursor role surfaces

- Raw `wl_surface` owner: `CursorRoleSurface`.
- Role object: pointer cursor surface selected by `wl_pointer.set_cursor` or
  bypassed by cursor-shape protocol.
- Scale behavior: cursor scale policy chooses theme image size and buffer scale.
- Output membership behavior: focused output scale is tracked by
  `CursorManager`, not exposed as a surface API.
- Damage behavior: cursor images are committed as full-buffer damage.
- Input and opaque regions: unsupported.
- Metadata and submit constraints: unsupported.
- Destroy order: `CursorManager.shutdown()` detaches and commits before
  destroying cursor surfaces so theme-owned buffers are not left attached.
- Late callback policy: seat removal, focus loss, and display teardown destroy
  or detach cursor surfaces through cursor seat state effects.

## Drag icon role surfaces

- Raw `wl_surface` owner: `DragIconRoleSurface`.
- Role object: data-device drag icon surface.
- Scale behavior: the supplied XRGB8888 image size defines the buffer size.
- Output membership behavior: not tracked as app-facing output state.
- Damage behavior: icon images are committed as full-buffer damage.
- Input and opaque regions: unsupported.
- Metadata and submit constraints: unsupported.
- Destroy order: drag cancel, finish, failed start, and display teardown retire
  SHM pools before destroying the raw surface.
- Late callback policy: data-transfer cleanup owns source cancellation and drag
  completion; late role cleanup is idempotent.

## Graphics preview backing

`WaylandGraphicsPreview` currently uses managed window software submission for
public preview paths. It forwards `WaylandGraphicsDamageRegion` to
`SurfaceDamageRegion?`, then relies on the same window commit path for
validation, clipping, first-buffer full damage, and logical-to-buffer mapping.
Raw GBM/EGL/DRM handles remain package-internal.

## Subsurfaces

Subsurfaces are graph-shaped managed surfaces. They use
`SurfaceRuntime<SubsurfaceRoleResources>` for scale, transaction, metadata, and
software damage behavior. Their parent/child lifecycle is window-owned and stays
out of `DisplayResourceTable`.

- Raw `wl_surface` owner: `SubsurfaceRoleSurface`.
- Role object: `wl_subsurface` created through an internal one-shot
  `wl_subcompositor` bind.
- Scale behavior: same `SurfaceRuntime` scale substrate as windows and popups.
- Output membership behavior: tracked internally through surface scale callbacks.
- Damage behavior: public logical damage follows the shared software commit path.
- Input and opaque regions: public `Subsurface` region APIs use one-shot
  `wl_region` objects and commit.
- Metadata behavior: available through the shared commit path when used
  internally.
- Submit constraints: available through the shared commit path when used
  internally.
- Destroy order: parent windows close managed subsurfaces before the parent role
  surface is destroyed; subsurface role resources are destroyed before the child
  raw surface.
- Late callback policy: pending frame state is cancelled during close and stale
  handles report typed display errors.
