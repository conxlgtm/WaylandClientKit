# Text Input Lifecycle

Text input is compositor/IME text entry through ``TextInputSession`` and
``TextInputEvents``. It is separate from local keyboard interpretation, key
symbols, shortcuts, and compose handling.

Use text input when an editable control wants compositor-assisted text entry,
IME composition, surrounding text, and cursor rectangle updates. Use
interpreted keyboard events for shortcuts, debug key logging, and local
keyboard text that does not require IME state.

## Capability Gate

Text input requires `zwp_text_input_manager_v3`. Create a seat-scoped session
with ``WaylandDisplay/textInputSession(for:)`` and read committed compositor
events from ``WaylandDisplay/textInputEvents``.

Input-panel show/hide requests require text-input protocol v2. WaylandClientKit
reports a typed unavailable-version error when the negotiated protocol version
does not support the request.

## Disable Semantics

Commit enabled request state first. Calling disable() finalizes the disable
request, so a separate `commit()` for the disabled state is unnecessary.

## Input Panel Hints

Use ``TextInputSession/showInputPanel()`` and
``TextInputSession/hideInputPanel()`` when a focused text field wants to hint
that an on-screen input panel should be shown or hidden. These requests are
compositor hints, not guarantees. Compositors can ignore them based on device,
keyboard, accessibility, shell, or policy state.

WaylandClientKit owns request ordering, seat identity, event publication, and typed
unavailable errors. Frameworks own focus policy, editable field state,
surrounding text model, preedit rendering, and when to enable or disable a
session.

## Example

See `TextInputSmoke` in `Examples/TextInputSmoke`.
