# Building A GUI Layer On WaylandClientKit

WaylandClientKit is ready to act as the low-level host for an experimental GUI
framework. It gives the framework Wayland lifecycle, typed events, managed
windows, software frames, diagnostics, and preview graphics facts. The framework
still owns the user-interface model.

## What WaylandClientKit Gives You

- `WaylandDisplay.withConnection` for connection lifetime and shutdown
- typed windows, popups, output snapshots, geometry, scale, and state snapshots
- software frame presentation through `Window.show` and `Window.redraw`
- logical input regions, opaque regions, and damage-aware software redraws
- redraw requests and `needsRedraw`
- display, input, text-input, data-transfer, presentation, and diagnostic streams
- pointer, keyboard, touch, tablet, text-input, clipboard, drag-and-drop, and
  cursor facts
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

Do not move those layers into WaylandClientKit.

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
7. Convert dirty rectangles into `SurfaceDamageRegion` when partial redraw is useful.
8. Draw into `SoftwareFrame` or submit through `WaylandGraphicsPreview`.
9. Close windows and cancel event tasks when `windowClosed` arrives.

Keep the render adapter platform-shaped. A useful adapter knows about windows,
geometry, redraw, and frame submission. It should not know about widgets.
Use WaylandClientKit's concrete public identities as described in
[`identity-model.md`](identity-model.md); do not invent raw-pointer routing or a
single framework-wide ID type.

## Framework-Facing Examples

Use these examples as references before adding framework policy:

- `ClientSideResizeChrome`: client-side edge/corner hit testing, cursor choice,
  two-window resize routing, and serial-preserving
  `requestInteractiveResize(seatID:serial:edge:)`.
- `SerialActionsProbe`: target window, seat ID, pointer serial, pointer
  location, decoration mode, capability, snapshot, and thrown-error logging for
  resize, move, and window-menu requests.
- `TwoWindowFrameworkHost`: independent per-window state, event routing by
  `WindowID`, startup registration before first show, and close handling that
  keeps the second window alive.
- `TwoWindowOrderStress`: high-volume two-window input routing with a larger
  input queue and controlled overflow diagnostics.
- `TextInputSmoke`: text-input capability, enable/disable lifecycle, IME
  commits, and interpreted keyboard fallback. `disable()` finalizes the
  session; do not call `commit()` after disabling.
- `TabletInputSmoke`: tablet protocol capability and typed device/tool/pad
  event facts. It skips cleanly when no compositor tablet protocol or hardware
  events are available.
- `DataTransferSmoke`: clipboard, primary-selection, drag/drop source and offer
  behavior, private MIME filtering, stale-offer handling, bounded reads, and
  source cancellation.
- `PresentationFeedbackAnimation`: redraw-driven animation and optional
  presentation feedback.
- `SurfaceRegionSmoke`: input and opaque region behavior with compositor
  defaults reset.
- `DamageRegionSmoke`: small animated logical damage regions mapped by
  WaylandClientKit before commit.
- `SubsurfaceSmoke`: managed child surface creation, software presentation,
  movement, and parent-owned cleanup.
- `surface-role-inventory.md`: internal role support matrix for windows,
  popups, cursor surfaces, drag icons, graphics preview, and subsurfaces.
- `FrameworkHostSmoke`: the smallest app-host loop that imports only public
  WaylandClientKit products.
- `GPUPreviewSmokeClient`: preview graphics capability and software-submission
  facts without exposing raw GPU handles.

The examples that can run unattended accept common flags:

```bash
--auto-close
--duration-seconds 3
--print-summary
```

`swift run swl test integration-framework-host` and `swift run swl ci release`
keep framework-facing handoff examples in build coverage.

## Software Rendering Path

Use `Window.show` for the first frame and `Window.redraw` after
`redrawRequested`. `SoftwareFrame.width` and `height` are buffer-pixel values.
`SoftwareFrame.geometry` maps between logical surface coordinates and buffer
pixels.

`show(damage:_:)` and `redraw(damage:_:)` accept logical
`SurfaceDamageRegion` values. WaylandClientKit validates damage passed to `show`,
but the first buffer-backed commit is still sent as full-frame damage because no
previous buffer contents exist. Later redraws map those rectangles to buffer
damage for the current scale and viewport path and clip partial overhang to the
surface bounds. Passing no damage uses full-frame damage. An empty damage region
is invalid because it would make the commit intent ambiguous.

Cursor and drag icon surfaces are managed visual surfaces, but they do not
accept public region, metadata, or partial-damage operations. They use full
buffer commits owned by their role-specific managers. See
[`surface-role-inventory.md`](surface-role-inventory.md) for the internal role
matrix.

Subsurfaces are platform child surfaces, not widgets. Use
`Window.createSubsurface(configuration:)` when a framework needs a compositor
visible child surface for embedded content, video, plugin-like surfaces, or
renderer layering. The framework owns layout and z-order policy; WaylandClientKit
owns protocol lifetime, software commits, and parent close cleanup.

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

WaylandClientKit preserves protocol identity. A framework should build its focus
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
- Color-management image descriptions remain internal.
- Static and animated custom cursor images are available. Animation frames use
  the same XRGB8888 format and hotspot validation as static cursor images.
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
