# WaylandClient

Connect to a Wayland compositor from Swift and build client-side Linux GUI
substrate code.

WaylandClientKit's public `WaylandClient` API covers display connection lifetime,
window and popup surfaces, software rendering through shared memory, input
events, keyboard interpretation, relative pointer and pointer constraints,
pointer gestures, pointer warp requests, tablet input, cursor requests, data
transfer, text-input sessions, XDG activation, desktop relationship hints,
presentation feedback, output topology, output-management preview facts,
compositor session-management preview facts, diagnostics, and capability
reporting.

GPU allocation and presentation experiments live in package-internal preview
targets.

## Topics

### Display Connection

- <doc:DisplayLifecycle>
- <doc:OutputTopology>
- ``WaylandDisplay``
- ``WaylandDisplayError``
- ``WaylandCapabilities``
- ``ProtocolAvailability``

### Windows And Popups

- <doc:WindowDrawing>
- <doc:SurfaceRegionsAndDamage>
- <doc:Subsurfaces>
- <doc:SessionReadiness>
- ``Window``
- ``WindowConfiguration``
- ``WindowRestorationSnapshot``
- ``PopupSurface``
- ``PopupConfiguration``
- ``Subsurface``
- ``SubsurfaceConfiguration``

### Rendering

- ``SoftwareFrame``
- ``SurfaceGeometry``
- ``SurfaceScale``
- ``OutputSnapshot``
- ``OutputID``
- ``OutputManagementSnapshot``
- ``SurfaceRegion``
- ``SurfaceDamageRegion``
- ``PositivePixelSize``

### Input

- <doc:InputAndTextInput>
- <doc:PointerCapture>
- <doc:TabletInput>
- ``InputEvent``
- ``SeatID``
- ``KeyboardKeyEvent``
- ``PointerEvent``
- ``RelativePointerMotionEvent``
- ``RelativePointerSubscription``
- ``PointerGestureSubscription``
- ``PointerGestureEvent``
- ``PointerConstraint``
- ``PointerConstraintLifecycleEvent``
- ``PointerCaptureError``
- ``PointerWarpError``
- ``TouchEvent``
- ``TabletEvent``
- ``TabletToolEvent``
- ``TabletPadEvent``

### Data Transfer

- <doc:DataTransferAndDragIcons>
- ``ClipboardOffer``
- ``ClipboardSource``
- ``PrimarySelectionOffer``
- ``PrimarySelectionSource``
- ``DragOffer``
- ``DragSource``
- ``DragIcon``
- ``ToplevelDrag``
- ``StartedToplevelDrag``

### Text Input

- <doc:TextInputLifecycle>
- ``TextInputSession``
- ``TextInputEvents``
- ``TextInputEvent``
- ``TextInputContentHints``
- ``TextInputContentPurpose``
- ``TextInputError``

### Activation

- <doc:ActivationAndFocusHandoff>
- <doc:DesktopIntegration>
- ``ActivationToken``
- ``ActivationTokenRequest``
- ``ActivationError``
- ``WindowIcon``
- ``IdleInhibitor``
- ``WindowDialog``
- ``KeyboardShortcutsInhibitor``
- ``ForeignToplevelListSnapshot``
- ``CompositorSessionEventSnapshot``

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
- ``PointerCursorScalePolicy``
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
