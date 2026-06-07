# Text Input Lifecycle

Text input is compositor/IME text entry through ``TextInputSession`` and
``TextInputEvents``. It is separate from local keyboard interpretation, key
symbols, shortcuts, and compose handling.

## When To Use This

Use text input when an editable control wants compositor-assisted text entry,
IME composition, surrounding text, and cursor rectangle updates. Use
interpreted keyboard events for shortcuts, debug key logging, and local
keyboard text that does not require IME state.

## Capability Gate

Text input requires `zwp_text_input_manager_v3`. Create a seat-scoped session
with ``WaylandDisplay/textInputSession(for:)`` and read committed compositor
events from ``WaylandDisplay/textInputEvents``.

## Public APIs

- ``TextInputSession``
- ``TextInputEvents``
- ``TextInputEvent``
- ``TextInputContentHints``
- ``TextInputContentPurpose``
- ``WaylandDisplay/textInputSession(for:)``
- ``WaylandDisplay/textInputEvents``

## Disable Semantics

Commit enabled text-input request state before calling disable. `disable()` finalizes
the disable request and should not be followed by a separate `commit()` for the
disabled state. This mirrors the protocol lifecycle and keeps the compositor from
seeing stale enabled text state after focus changes.

In plain protocol-ordering terms, disable() finalizes the text-input disable
request.

## Errors And Policy

SwiftWayland owns request ordering, seat identity, event publication, and typed
unavailable errors. Frameworks own focus policy, editable field state,
surrounding text model, preedit rendering, and when to enable or disable a
session.

## Example

See `TextInputSmoke` in `Examples/TextInputSmoke`.
