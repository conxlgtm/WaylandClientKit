# WaylandClient

Connect to a Wayland compositor from Swift and build client-side Linux GUI
substrate code without taking on a widget toolkit, scene graph, or renderer.

SwiftWayland's public `WaylandClient` API covers display connection lifetime,
window and popup surfaces, software rendering through shared memory, input
events, keyboard interpretation, cursor requests, data transfer, text-input
sessions, XDG activation, presentation feedback, diagnostics, and capability
reporting.

GPU allocation and presentation experiments live in package-internal preview
targets. They are not public `WaylandClient` API.

## Topics

### Display Connection

- <doc:DisplayLifecycle>
- ``WaylandDisplay``
- ``WaylandDisplayError``
- ``WaylandCapabilities``
- ``ProtocolAvailability``

### Windows And Popups

- <doc:WindowDrawing>
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

- <doc:InputAndTextInput>
- ``InputEvent``
- ``SeatID``
- ``KeyboardKeyEvent``
- ``PointerEvent``
- ``TouchEvent``

### Data Transfer

- <doc:DataTransferAndDragIcons>
- ``ClipboardOffer``
- ``ClipboardSource``
- ``PrimarySelectionOffer``
- ``PrimarySelectionSource``
- ``DragOffer``
- ``DragSource``
- ``DragIcon``

### Text Input

- <doc:InputAndTextInput>
- ``TextInputSession``
- ``TextInputEvents``
- ``TextInputEvent``
- ``TextInputContentHints``
- ``TextInputContentPurpose``
- ``TextInputError``

### Activation

- <doc:ActivationAndFocusHandoff>
- ``ActivationToken``
- ``ActivationTokenRequest``
- ``ActivationError``

### Capabilities

- <doc:CapabilitiesAndOptionalProtocols>
- ``WaylandCapabilities``
- ``ProtocolAvailability``

### Event Streams

- <doc:EventStreamsAndOverflow>
- ``DisplayEvents``
- ``InputEvents``
- ``TextInputEvents``
- ``DataTransferEvents``

### Cursor

- <doc:CursorShapeAndThemeFallback>
- ``PointerCursor``
- ``CursorConfiguration``
- ``CursorRequestResult``

### Presentation

- <doc:PresentationFeedbackAndFrameCallbacks>
- ``WindowPresentationEvents``
- ``PresentationFeedback``

### Diagnostics

- <doc:DiagnosticsAndDisplayFailures>
- ``DisplayDiagnostic``
- ``WindowDiagnostic``
- ``TextInputDiagnostic``
- ``WaylandDisplayError``
