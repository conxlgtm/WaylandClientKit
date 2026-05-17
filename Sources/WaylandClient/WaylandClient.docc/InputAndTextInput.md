# Input And Text Input

``InputEvent`` reports compositor input events, interpreted keyboard facts, and
input diagnostics. It is appropriate for pointer routing, shortcuts, keyboard
state, touch handling, and low-level seat changes.

``TextInputSession`` is separate. It models compositor/IME text entry through
text-input-v3 and publishes ``TextInputEvent`` values on ``TextInputEvents``.
Use text input for editable text fields that need IME, preedit, surrounding-text,
content-purpose, and cursor-rectangle protocol behavior.

Enable a session for a window before sending request-side state such as
surrounding text, text-change cause, content type, cursor rectangle, or commit.
Requests made before enable or after a disabled/inactive transition throw a
typed ``TextInputError`` and may publish a ``TextInputDiagnostic``.

Keyboard interpretation can produce simple key text, but it is not a replacement
for compositor text input.
