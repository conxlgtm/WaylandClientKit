# Desktop Integration

Desktop integration covers optional compositor-mediated affordances that are
outside the core drawing path: window icons, idle inhibition, xdg-dialog hints,
keyboard shortcut inhibition, toplevel-drag start, read-only foreign toplevel
capability reporting, and system bell.

## When To Use This

Use a window icon when the compositor or shell can display app identity. Use
idle inhibition while visible activity such as media playback should keep the
screen awake. Use `createDialog(parent:modal:)` to expose the protocol fact that
one toplevel is a dialog relative to another toplevel. Use keyboard shortcut
inhibition only for seat/window-scoped full-screen or capture-heavy modes, and
watch display events for `keyboardShortcutsInhibitorChanged` because the
compositor can activate or deactivate the request. Use `startToplevelDrag` when
a drag source should move detachable toplevel content. Foreign toplevel list
event-backed facts are deferred until the raw protocol state is modeled. Use
system bell for compositor-mediated attention feedback rather than playing sound
directly from WaylandClientKit.

## Capability Gates

- ``Window/setIcon(_:)`` requires `xdg_toplevel_icon_manager_v1`.
- ``Window/inhibitIdle()`` requires `zwp_idle_inhibit_manager_v1`.
- ``Window/createDialog(parent:modal:)`` requires `xdg_wm_dialog_v1`.
- ``Window/startToplevelDrag(source:seatID:serial:icon:offset:)`` requires
  `xdg_toplevel_drag_manager_v1`; it creates the drag source and toplevel-drag
  object before the compositor `start_drag` request.
- ``Window/inhibitKeyboardShortcuts(seatID:)`` requires
  `zwp_keyboard_shortcuts_inhibit_manager_v1`.
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
- ``WindowDialog``
- ``KeyboardShortcutsInhibitor``
- ``ToplevelDrag``
- ``StartedToplevelDrag``
- ``Window/setIcon(_:)``
- ``Window/inhibitIdle()``
- ``Window/createDialog(parent:modal:)``
- ``Window/inhibitKeyboardShortcuts(seatID:)``
- ``Window/startToplevelDrag(source:seatID:serial:icon:offset:)``
- ``WaylandDisplay/ringSystemBell()``
- ``Window/ringSystemBell()``

## Errors And Policy

WaylandClientKit owns protocol request validation and typed unavailable errors.
Frameworks own app identity, icon asset selection, idle policy, modal event
filtering, sheet/alert/document-modal behavior, shortcut policy, drag/drop
policy, and user-visible attention policy.

## Examples

See `WindowIconSmoke`, `IdleInhibitSmoke`, `DialogSmoke`,
`KeyboardShortcutsInhibitSmoke`, `ToplevelDragSmoke`, and `SystemBellSmoke` in
`Examples/`.
