# Desktop Integration

Desktop integration covers optional compositor-mediated affordances that are
outside the core drawing path: window icons, idle inhibition, and system bell.

## When To Use This

Use a window icon when the compositor or shell can display app identity. Use
idle inhibition while visible activity such as media playback should keep the
screen awake. Use system bell for compositor-mediated attention feedback rather
than playing sound directly from SwiftWayland.

## Capability Gates

- ``Window/setIcon(_:)`` requires `xdg_toplevel_icon_manager_v1`.
- ``Window/inhibitIdle()`` requires `zwp_idle_inhibit_manager_v1`.
- ``WaylandDisplay/ringSystemBell()`` and ``Window/ringSystemBell()`` require
  `xdg_system_bell_v1`.

Check ``WaylandDisplay/capabilities()`` first, but still handle request-time
errors because optional globals can disappear and compositor policy can reject
or ignore a request.

## Public APIs

- ``WindowIcon``
- ``WindowIconName``
- ``WindowIconImage``
- ``IdleInhibitor``
- ``Window/setIcon(_:)``
- ``Window/inhibitIdle()``
- ``WaylandDisplay/ringSystemBell()``
- ``Window/ringSystemBell()``

## Errors And Policy

SwiftWayland owns protocol request validation and typed unavailable errors.
Frameworks own app identity, icon asset selection, idle policy, and user-visible
attention policy.

## Examples

See `WindowIconSmoke`, `IdleInhibitSmoke`, and `SystemBellSmoke` in `Examples/`.

