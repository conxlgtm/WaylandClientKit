# WaylandClient

Connect to a Wayland compositor from Swift and build client-side Linux GUI
substrate code without taking on a widget toolkit, scene graph, or renderer.

SwiftWayland's public `WaylandClient` API covers display connection lifetime,
window and popup surfaces, software rendering through shared memory, input
events, keyboard interpretation, cursor requests, data transfer, presentation
feedback, diagnostics, and capability reporting.

GPU allocation and presentation experiments live in package-internal preview
targets. They are not public `WaylandClient` API.

## Topics

### Display Connection

- ``WaylandDisplay``
- ``WaylandDisplayError``
- ``WaylandCapabilities``
- ``ProtocolAvailability``

### Windows And Popups

- ``Window``
- ``WindowConfiguration``
- ``Popup``
- ``PopupConfiguration``

### Rendering

- ``WindowDrawingContext``
- ``PixelBuffer``
- ``SurfaceScale``

### Input

- ``InputEvent``
- ``SeatID``
- ``KeyboardKeyEvent``
- ``PointerEvent``
- ``TouchEvent``

### Data Transfer

- ``ClipboardOffer``
- ``ClipboardSource``
- ``PrimarySelectionOffer``
- ``PrimarySelectionSource``
- ``DragOffer``
- ``DragSource``

### Diagnostics

- ``DisplayDiagnostic``
- ``WindowDiagnostic``
- ``WaylandSystemError``

