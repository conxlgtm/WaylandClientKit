# Desktop Integration

Desktop integration covers optional compositor-mediated affordances that are
outside the core drawing path: window icons, idle inhibition, xdg-dialog hints,
keyboard shortcut inhibition, toplevel-drag start, read-only foreign toplevel
facts, and system bell.

Window icons carry app identity. Idle inhibition keeps the screen awake during
visible activity. Dialog hints relate toplevels. Shortcut inhibition serves
seat- and window-scoped capture modes, with lifecycle changes reported through
display events. Toplevel drag moves detachable content. Foreign toplevel
snapshots provide read-only, connection-local facts; titles and app IDs are
optional and privacy-sensitive. System bell requests compositor-mediated
attention feedback.

## Capability Gates

- ``Window/setIcon(_:)`` requires `xdg_toplevel_icon_manager_v1`.
- ``Window/inhibitIdle()`` requires `zwp_idle_inhibit_manager_v1`.
- ``Window/createDialog(parent:modal:)`` requires `xdg_wm_dialog_v1`.
- ``Window/startToplevelDrag(source:seatID:serial:icon:offset:)`` requires
  `xdg_toplevel_drag_manager_v1`. It creates the drag source and toplevel-drag
  object before the compositor `start_drag` request.
- ``Window/inhibitKeyboardShortcuts(seatID:)`` requires
  `zwp_keyboard_shortcuts_inhibit_manager_v1`.
- ``WaylandDisplay/foreignToplevelListSnapshot(timeoutMilliseconds:)`` requires
  `ext_foreign_toplevel_list_v1`.
- ``WaylandDisplay/ringSystemBell()`` and ``Window/ringSystemBell()`` require
  `xdg_system_bell_v1`.

Check ``WaylandDisplay/capabilities()`` first, but still handle request-time
errors because startup globals can disappear and compositor policy can reject
or ignore a request.

WaylandClientKit validates requests and reports typed availability errors.
Frameworks own asset, idle, modal, shortcut, drag, privacy, and attention policy.

## Examples

See `WindowIconSmoke`, `IdleInhibitSmoke`, `DialogSmoke`,
`KeyboardShortcutsInhibitSmoke`, `ToplevelDragSmoke`,
`ForeignToplevelListSmoke`, and `SystemBellSmoke` in `Examples/`.
