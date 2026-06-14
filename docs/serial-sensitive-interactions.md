# Serial-Sensitive Interactions

Wayland requests such as interactive resize, move, window menu, and source-side
drag depend on a seat and a compositor serial captured from an input event.
Frameworks should keep those values attached to the button press that produced
the action.

Use this flow for serial-sensitive actions:

```text
button press
-> capture seat ID, serial, target, and pointer location
-> decide the action
-> send the request before unrelated awaited work
```

Unrelated awaited work can let more protocol events arrive before the request is
sent. That can make the compositor treat the serial as stale or make framework
routing choose a different target. A framework may update retained state after
the request, but it should not abstract away the event identity before deciding
the action.

## Interactive Resize

Use `InputEvent.windowID` or the surface target in `InputEvent.target` to choose
the window that received the press. Use the pointer location in logical surface
coordinates to hit-test edges and corners, then call:

```swift
try await window.requestInteractiveResize(
    seatID: event.seatID,
    serial: button.serial,
    edge: edge
)
```

`WindowResizeEdge` is the protocol request value. WaylandClientKit does not decide
which pixels count as resize chrome, which cursor to show, or which windows are
eligible for client-side resizing.

## Interactive Move

For a press in framework-owned titlebar or drag chrome, preserve the same
`SeatID` and `PointerButtonEvent.serial`, then call:

```swift
try await window.requestInteractiveMove(
    seatID: event.seatID,
    serial: button.serial
)
```

The framework owns titlebar hit testing and any policy that prevents moving a
maximized, fullscreen, or constrained window.

## Window Menu

For a press or shortcut that should open the compositor window menu, preserve
the current seat, serial, and logical position, then call:

```swift
try await window.requestWindowMenu(
    seatID: event.seatID,
    serial: button.serial,
    position: menuPosition
)
```

The position should be in the target window's logical coordinate space.

## Source-Side Drag

For source-side drag-and-drop, start the drag directly from the button press
that begins the drag gesture:

```swift
let source = try await window.startDrag(
    source: configuration,
    seatID: event.seatID,
    serial: button.serial,
    icon: dragIcon
)
```

The framework owns gesture recognition, MIME selection, drag icon policy, and
source cancellation. WaylandClientKit exposes the serial-sensitive request and the
typed drag-source lifecycle events.

## XDG Activation

Activation token requests can include the same seat and serial context when they
are triggered by user input:

```swift
let token = try await window.requestActivationToken(
    appID: "org.example.App",
    serialContext: ActivationSerialContext(
        seatID: event.seatID,
        serial: button.serial
    )
)
try await window.activate(using: token)
```

The token is opaque and compositor policy may still decline or ignore the later
activate request. WaylandClientKit preserves the serial, surface, and app ID facts;
the framework owns launch, command routing, and user-facing focus policy.

## Multi-Window Routing

In a multi-window host, route surface-targeted pointer presses by public identity
values before using broader focus fallback. Keep a registry keyed by `WindowID`
and dispatch the request to the controller for the event target. Keyboard focus
is not a safe substitute for a surface-targeted pointer press.

`Examples/ClientSideResizeChrome` shows the resize path with edge/corner hit
testing and two windows. `Examples/SerialActionsProbe` logs the full request
context for resize, move, and window-menu requests so compositor-specific
behavior can be copied into matrix notes.
