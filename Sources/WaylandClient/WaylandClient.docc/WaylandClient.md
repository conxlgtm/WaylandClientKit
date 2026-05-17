# WaylandClient

Connect to a Wayland compositor from Swift and build client-side Linux GUI
substrate code without taking on a widget toolkit, scene graph, or renderer.

SwiftWayland's public `WaylandClient` API covers display connection lifetime,
window and popup surfaces, software rendering through shared memory, input
events, keyboard interpretation, cursor requests, data transfer, text-input
sessions, presentation feedback, diagnostics, and capability reporting.

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
- ``PopupSurface``
- ``PopupConfiguration``

### Rendering

- ``SoftwareFrame``
- ``SurfaceGeometry``
- ``SurfaceScale``
- ``PositivePixelSize``

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
- ``DragIcon``

### Text Input

- ``TextInputSession``
- ``TextInputEvents``
- ``TextInputEvent``
- ``TextInputContentHints``
- ``TextInputContentPurpose``
- ``TextInputError``

### Diagnostics

- ``DisplayDiagnostic``
- ``WindowDiagnostic``
- ``WaylandDisplayError``
