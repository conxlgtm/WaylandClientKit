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
transactions from ``WaylandDisplay/textInputEvents``. The same events appear
in the complete, cross-family ordered ``WaylandDisplay/events`` feed.

Input-panel show/hide requests require text-input protocol v2. WaylandClientKit
reports a typed unavailable-version error when the negotiated protocol version
does not support the request.

## Disable Semantics

``TextInputSession/disable()`` sends the protocol disable request followed by
the required commit, then marks the session disabled. It returns the commit
serial, or `nil` when the session is already inactive or disabled. Do not call
`commit()` after disabling; the automatic commit is the complete disable
contract.

## Commits And Transactions

``TextInputSession/commit()`` returns a ``TextInputCommitSerial``. Serial
values advance with wrapping arithmetic after each successfully issued commit.

The compositor's preedit, deletion, committed text, and action changes are
published together as one ``TextInputTransaction`` when the protocol sends
`done`. An action includes its independent protocol serial. The transaction
includes the compositor's current ``InputEventTarget`` and never requires a
client to reconstruct focus.

Apply each transaction atomically in the protocol-required order. Skip an
operation when its optional payload is absent, but do not reorder the operations
that are present:

1. Remove the existing preedit and replace it with the editor cursor.
2. Apply ``TextInputTransaction/deletion`` to the surrounding text.
3. Insert ``TextInputTransaction/committedText`` with the cursor at its end.
4. Update the surrounding-text state that the client will send next.
5. Insert the new ``TextInputTransaction/preedit`` at the cursor.
6. Place the cursor or selection inside that preedit from `cursorBegin` and
   `cursorEnd`.
7. Perform the requested ``TextInputTransaction/action``.

The transaction's
``TextInputTransaction/matchesLatestCommit`` value reports whether the
compositor serial equals the session's latest issued commit. Clients must apply
all compositor changes even when this value is `false`; the match only determines
which client-side text-input request state corresponds to the transaction.

When the value is `false`, retain desired surrounding text, content type, and
cursor rectangle state in the client, but defer sending those setters in
response to the stale transaction. After a later transaction reports
`matchesLatestCommit == true`, reissue every retained setter and call
``TextInputSession/commit()``. WaylandClientKit forwards setters immediately; it
does not queue or replay this state during serial resynchronization.

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
