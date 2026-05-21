# Building A GUI Layer On SwiftWayland

SwiftWayland is ready to act as the low-level host for an experimental GUI
framework. It gives the framework Wayland lifecycle, typed events, managed
windows, software frames, diagnostics, and preview graphics facts. The framework
still owns the user-interface model.

## What SwiftWayland Gives You

- `WaylandDisplay.withConnection` for connection lifetime and shutdown
- typed windows, popups, output snapshots, geometry, scale, and state snapshots
- software frame presentation through `Window.show` and `Window.redraw`
- redraw requests and `needsRedraw`
- display, input, text-input, data-transfer, presentation, and diagnostic streams
- pointer, keyboard, touch, text-input, clipboard, drag-and-drop, and cursor facts
- `WaylandGraphicsPreview` capability, runtime-path, fallback, and managed
  software-submission APIs
- external integration tests that compile as separate packages

## What Your Framework Owns

- retained view model and diffing
- layout and measurement
- drawing command generation
- widgets, controls, gestures, and text editor behavior
- focus policy above protocol target identity
- animation timing policy
- damage tracking strategy
- app lifecycle and commands
- accessibility semantics
- renderer selection and fallback policy

Do not move those layers into SwiftWayland.

## Recommended First Architecture

Start software-first:

1. Wrap `WaylandDisplay.withConnection` in your app host.
2. Keep a registry of `WindowID` to framework window state.
3. Consume `DisplayEvents`, `InputEvents`, `TextInputEvents`, and diagnostics in
   sibling tasks.
4. Route input with `InputEvent.target`, `InputEvent.windowID`, and
   `InputEvent.popup`.
5. Convert framework invalidations into `Window.requestRedraw()`.
6. On `DisplayEvent.redrawRequested`, produce a frame from your retained tree.
7. Draw into `SoftwareFrame` or submit through `WaylandGraphicsPreview`.
8. Close windows and cancel event tasks when `windowClosed` arrives.

Keep the render adapter platform-shaped. A useful adapter knows about windows,
geometry, redraw, and frame submission. It should not know about widgets.

## Software Rendering Path

Use `Window.show` for the first frame and `Window.redraw` after
`redrawRequested`. `SoftwareFrame.width` and `height` are buffer-pixel values.
`SoftwareFrame.geometry` maps between logical surface coordinates and buffer
pixels.

For framework experiments that want one graphics-facing boundary, use
`WaylandGraphicsPreview`:

```swift
let backing = try await display.createGraphicsWindowBacking(
    windowConfiguration: windowConfiguration,
    graphicsConfiguration: WaylandGraphicsConfiguration(fallbackPolicy: .forceSoftware)
)

let lease = try await backing.nextFrame()
let result = try await lease.submitSoftware { frame in
    renderer.draw(rootView, into: frame)
}
```

The result reports runtime path, operation (`show` or `redraw`), and submitted
buffer size. The public preview path does not claim presentation feedback was
observed. Presentation feedback remains a separate event stream.

## Graphics Preview Path

`WaylandGraphicsPreview` is renderer-neutral and preview-only. It exposes:

- `WaylandGraphicsSurfaceCapabilities`
- `WaylandGraphicsRuntimePath`
- `WaylandGraphicsFallbackPolicy`
- `WaylandGraphicsConfiguration`
- `WaylandGraphicsWindowBacking`
- `WaylandGraphicsFrameLease`
- `WaylandGraphicsFrameResult`
- `WaylandGraphicsFrameMetadata`
- `WaylandGraphicsDamageRegion`

Managed public GPU submission is not implemented yet. The current backing
supports software fallback and arbitrary software drawing through a single-use
lease. The API is shaped so a framework can later switch a backing policy
without exposing raw handles.

## Event Stream Handling

Use separate streams. Do not collapse everything into an untyped app event.

- `DisplayEvents`: lifecycle, redraw, output changes, aggregate input, aggregate diagnostics
- `InputEvents`: seat-scoped pointer, keyboard, touch, and input diagnostics
- `TextInputEvents`: IME/text-input focus, preedit, commit, delete, action, language, done
- `DataTransferEvents`: clipboard, primary selection, drag-and-drop offers and sources
- `WindowPresentationEvents`: `wp_presentation` feedback per window
- `DisplayDiagnostics`: dropped events and degraded-path diagnostics

Set `EventStreamConfiguration` capacities deliberately. If a framework blocks
event consumers long enough to overflow streams, diagnostics should be handled
as framework feedback, not ignored.

## Focus And Text Input

SwiftWayland preserves protocol identity. A framework should build its focus
model from:

- pointer enter/leave target identity
- keyboard enter/leave target identity
- `TextInputEvent.entered` and `.left`
- popup target and parent window identity
- seat IDs and input serials

The framework owns higher-level focus rules, such as focus scopes, tab order,
menu focus, text editor focus, and accessibility focus.

## Clipboard And Drag/Drop

Use the public source and offer APIs. Clipboard and primary selection are
selection protocols with compositor validation; ownership requests are not
synchronous proof of acceptance. Source-side drag requires an input serial and
can be cancelled through `DragSource.cancel()`.

Do not expose raw file descriptors or Wayland data-source objects to the
framework's widget layer. Keep data transfer at the app-host boundary.

## Known Gaps

- Public managed GPU submission is not implemented.
- Partial damage is represented in `WaylandGraphicsDamageRegion`, but managed
  preview submission currently reports unsupported partial damage.
- Color-management image descriptions remain internal.
- Public cursor animation and per-output cursor policy APIs are not available.
- Output-management APIs are out of scope.
- `WaylandGraphicsPreview` remains source-breaking preview API.

## Friction Detectors

These packages exercise the framework-consumer surface from outside the main
package:

- `IntegrationTests/FrameworkHostClient`
- `IntegrationTests/TinyUIPrototype`
- `IntegrationTests/GraphicsPreviewClient`

They must keep importing only public products. Any need for `WaylandRaw`,
`WaylandRuntime`, `WaylandGraphicsCore`, `WaylandGPUPreview`, or `@testable`
imports should become an API issue or a documented follow-up.
