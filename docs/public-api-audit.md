# Public API Audit

This audit records the current API boundary for the experimental `WaylandClient`
product. There is no compatibility promise yet, but public declarations in this
product should still be treated as intentional user-facing API.

## Products

### `WaylandClient`

Only library product. The raw, keyboard interpretation, and cursor modules are
implementation targets for this product, not separately vended library products.

Intentionally public:

- `WaylandDisplay`
- `Window`
- `PopupSurface`
- `WindowConfiguration`
- `WindowDecorationPreference`
- `WindowDecorationMode`
- `PopupConfiguration`
- `PopupPositioner`
- `PopupPlacement`
- `PopupLifecycleEvent`
- `SurfaceScale`
- `SurfaceGeometry`
- `SoftwareFrameGeometry`
- `PositivePixelSize`
- `SoftwareFrame`
- `DisplayEvent`
- `DisplayDiagnostic`
- `DiagnosticSeverity`
- `DisplayEvents`
- `InputEvents`
- `DataTransferEvents`
- `DisplayDiagnostics`
- `WaylandDisplayError`
- `InputEvent`
- `InputEventKind`
- `SeatCapabilities`
- `SeatID`
- `WindowID`
- `PopupSurfaceIdentity`
- public pointer, keyboard, and touch event payloads
- public raw and interpreted keyboard event payloads
- `PointerCursor`
- `CursorRequestResult`
- `CursorConfiguration`
- `ClipboardOffer`
- `ClipboardSource`
- `ClipboardSourceConfiguration`
- `ClipboardSourcePayload`
- `ClipboardOfferIdentity`
- `ClipboardSourceIdentity`
- `ClipboardSelectionEvent`
- `DataTransferEvent`
- `DataTransferDiagnostic`
- `MIMEType`
- `OwnedFileDescriptor`
- `ByteCount`
- `ClientError`

Current user-facing contract:

- `WaylandClient` is the only supported import for downstream users.
- Display connection, window creation and close, request-redraw, software
  XRGB8888 drawing, basic pointer/keyboard/touch events, interpreted keyboard
  payloads, server-side decoration negotiation, scale-aware window geometry,
  popup surfaces, regular clipboard selection, cursor requests, diagnostics,
  and terminal display errors are the current product surface.
- Public event and diagnostic enums are machine-matchable. String descriptions
  are derived display text, not control-flow payloads.
- Raw keycodes, raw pointer button values, raw axis values, and unknown future
  protocol values are intentionally preserved when useful to clients.
- Interpreted keyboard events expose local keyboard text through
  `KeyboardTextResult`. Shortcut matching should still use `keySymbols`,
  `primaryKeySymbol`, and modifiers. This is not text-input or IME support.
- Raw keymap bytes, raw file descriptors, raw proxies, listener owners, event
  queues, SHM pool internals, and owner-thread executor machinery are not
  product API.
- `SoftwareFrame` is a scoped borrowed drawing surface. User code may draw
  during the callback and may not retain frame storage beyond that callback.
- Window sizes are logical surface sizes. `SurfaceGeometry` records the
  logical size, buffer-pixel size, and exact `SurfaceScale` used by the
  current SHM frame.
- Regular clipboard means `wl_data_device_manager` selection offers and sources.
  Primary selection and drag-and-drop transfer handling are not part of this
  contract.

Intentionally package-internal:

- `DisplaySession`
- `TopLevelWindow`

Notes:

- `WaylandDisplay` is the high-level async surface. It is an actor backed by a
  dedicated Wayland owner-thread executor. The executor owns the integrated pump loop.
  display/input event streams are passive subscribers and do not drive Wayland dispatch.
- Display streams terminate normally on explicit close and terminate with
  `WaylandDisplayError` on fatal display failure or per-subscriber overflow.
- Nonterminal runtime degradation is surfaced through `DisplayEvent.diagnostic`.
  Input-specific diagnostics also remain available on `inputEvents`.
- `Window` is the ergonomic async handle. Windows are still addressable by `WindowID`,
  and teardown is routed through `WaylandDisplay.closeWindow(_:)` or
  `WaylandDisplay.close()`.
- `PopupSurface` is the public popup handle. Popup lifecycle display events carry
  the popup identity and parent window identity.
- `Window.decorationMode` reports the current effective xdg-decoration mode when
  the compositor supports `zxdg_decoration_manager_v1`. Mode absence is explicit
  as `.unavailable`.
- `Window.geometry` reports the current logical surface size, buffer-pixel size,
  and scale. The value is derived from the current xdg configure size and the
  active preferred integer or fractional surface scale.
- The runtime is single-thread-affine. Thread-affine session/window entry points are
  package implementation details. Downstream users should go through `WaylandDisplay`
  and `Window`.
- `TopLevelWindow` is currently tied to SHM software drawing and is not public API.
- `SoftwareFrame` is noncopyable and borrowed by drawing callbacks. User code can draw
  through row spans during the callback, but cannot copy the frame out and mutate the
  SHM storage after presentation.
- `SoftwareFrame.width` and `SoftwareFrame.height` are buffer-pixel dimensions.
  `SoftwareFrame.geometry.logicalSize` remains the surface-local logical size
  used for layout and input coordinate interpretation.
- `KeyboardEvent.raw` carries raw protocol keyboard facts.
- `KeyboardEvent.interpreted` carries xkbcommon-backed key symbols, simple UTF-8 values,
  modifier state updates, repeat info, and diagnostics.
- UTF-8 values from interpreted key events are not text-input protocol output.
- Cursor management is display-level. `PointerCursor` names theme cursors, and
  `WaylandDisplay.setPointerCursor(_:)` applies the desired cursor to focused seats.
  Explicit cursor changes throw when the cursor stack cannot fulfill the request.
- Clipboard offers are seat-scoped. `ClipboardOffer.read` performs a bounded read
  with a timeout, and `ClipboardSourceConfiguration` represents local regular
  clipboard payloads.
- `WindowDecorationPreference.preferServerSide` is the default because SwiftWayland
  does not draw client-side titlebars. `preferClientSide` requests no server-side
  decorations. Applications remain responsible for any custom chrome they want.
- `WaylandDisplay.withConnection` does not eagerly require a cursor theme to load.
  Cursor theme loading is deferred until a visible cursor image is first needed.
- `WaylandDisplay.withConnection`, `Window.show`, and `PopupSurface.show` use finite
  default waits. Callers must opt into longer waits by passing an explicit timeout.
- The `WaylandClient` target enables Swift strict memory-safety diagnostics as errors.
  Unsafe storage is confined to audited bridging points, currently `SoftwareFrame`.
- `WaylandRaw` has a strict memory-safety warning budget checked by
  `make strict-memory-safety-raw`. That target is not yet warning-free because it owns
  the intentional C boundary, but new raw unsafe surface area should not increase.

## Implementation Targets

These targets are package-internal architecture units:

- `WaylandRaw`: low-level protocol-shaped wrappers, raw input capture, and copied keymap payloads.
- `WaylandKeyboard`: xkbcommon-backed interpretation of copied `xkb_v1` keymaps.
- `WaylandCursor`: wayland-cursor theme loading and cursor image lifetime handling.

They may contain `public` declarations for cross-target compilation mechanics, but they are
not vended as package library products.

Run `./scripts/ci/dump-public-api.sh` during public API review and compare the
output against this audit. Any new public declaration in `WaylandClient` should
be classified as product API, raw-preserving API, diagnostic/error API, or
temporary API to remove before a public compatibility policy exists.

## Stable Raw-Preserving Values

These are expected to remain public because applications need protocol facts:

- raw keyboard keycodes,
- raw keyboard key state values,
- raw pointer button values,
- raw pointer axis values,
- touch IDs and coordinates,
- seat/window IDs,
- unknown future raw values in public event wrappers.

These are not expected to become public product API:

- `RawOwnedProxy`,
- raw Wayland object pointers,
- raw event queues,
- raw listener owners,
- raw keymap file descriptors or mmap data,
- SHM pool and buffer implementation details,
- executor or event-loop internals.

## Access Level Rules

Use the narrowest access level that works:

```text
private
internal
package
public
```

Use `package` for cross-target implementation details.

Use `public` only for downstream package API.

## Sendable Review

Public event payloads are value-shaped and can be `Sendable`.

Do not add `@unchecked Sendable` without a documented exception and review. Current lint rules reject it.

## Development Contract

The public API may break while SwiftWayland is experimental.

Before treating a public declaration as intentional:

1. Run `./scripts/ci/dump-public-api.sh`.
2. Review all new `WaylandClient` public declarations.
3. Confirm non-product public declarations are still outside the manifest's
   library products.
4. Update this audit if the current public contract changes.
