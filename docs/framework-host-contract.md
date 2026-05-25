# Framework Host Contract

This document describes the public SwiftWayland surface a future GUI framework
should build on. It is written for a downstream framework author. SwiftWayland
is the Wayland substrate: it owns display connection, protocol lifetime,
typed events, software frame presentation, capability reporting, diagnostics,
and preview graphics facts. It does not own retained view trees, layout,
widgets, styling, gestures, render graphs, application commands, or accessibility
semantics.

## APIs To Use First

Start with these public APIs:

- `WaylandDisplay.withConnection(...)`
- `DisplayConfiguration`, `EventStreamConfiguration`, and `InputPipelineConfiguration`
- `WaylandDisplay.capabilities()`, `outputs()`, and `diagnostics`
- `WaylandDisplay.events`, `inputEvents`, `textInputEvents`, and `dataTransferEvents`
- `WaylandDisplay.createTopLevelWindow(configuration:)`
- `Window.show`, `redraw`, `requestRedraw`, `needsRedraw`, `geometry`, and `stateSnapshot`
- `Window.presentationEvents` and `requestPresentationFeedback()`
- `Window.createPopup(configuration:)`
- `ActivationToken`, `ActivationTokenRequest`, and
  `Window.requestActivationToken(...)` for compositor-mediated focus handoff
- `TextInputSession` and `WaylandDisplay.textInputSession(for:)`
- clipboard, primary-selection, and drag-and-drop source and offer APIs
- cursor APIs through `PointerCursor`, `CursorConfiguration`, and `setPointerCursor(_:)`
- preview graphics APIs in `WaylandGraphicsPreview` when the framework wants
  renderer-neutral capability and software submission experiments

Do not depend on `WaylandRaw`, `WaylandRuntime`, `WaylandGraphicsCore`,
`WaylandGPUPreview`, package-only symbols, or `@testable` imports.

For requests that depend on input serials, see
[`serial-sensitive-interactions.md`](serial-sensitive-interactions.md).

## Display Lifecycle

Use `WaylandDisplay.withConnection` as the default host boundary. It opens the
Wayland connection, starts the owner-thread event integration, runs the body, and
closes the display on normal return or thrown error.

Call `display.close()` only when the framework is deliberately ending the
session early. Closing finishes event streams and makes later display/window
operations fail with typed closed-display errors.

A framework should treat the display actor as the Wayland owner. It should not
try to drive the raw display fd, dispatch queue, or flush/read sequence itself.

## Window Lifecycle

Create toplevels with `createTopLevelWindow(configuration:)`. A `Window` is a
typed handle tied to its owning display. `Window.close()` destroys the managed
window; compositor close requests arrive as `DisplayEvent.windowCloseRequested`.

`show` is the first presentation operation. It waits for the initial configure
and commits the first software frame. `redraw` is for later frames. A framework
should use `requestRedraw()` when state changes and wait for
`DisplayEvent.redrawRequested(windowID)` before calling `redraw`.

Use `needsRedraw` as a guard when coalescing invalidations. Use `geometry` and
`stateSnapshot` after configure/redraw events to update layout inputs. Geometry
is reported as logical size, buffer-pixel size, and rational scale.

## Event Stream Ownership

SwiftWayland intentionally keeps event families separate:

- `DisplayEvents` for lifecycle, redraw, output, and aggregate input/diagnostic events
- `InputEvents` for seat-scoped pointer, keyboard, and touch payloads
- `TextInputEvents` for compositor/IME text-entry events
- `DataTransferEvents` for clipboard, primary-selection, and drag-and-drop events
- `WindowPresentationEvents` for presentation-time feedback per window
- `DisplayDiagnostics` for overflow and degraded-path reporting

A framework can consume these concurrently in a task group. Do not erase payload
types into strings. Keep typed events and route by `WindowID`, `PopupSurfaceIdentity`,
`SeatID`, and source/offer identities.

Stream capacities are configured through `EventStreamConfiguration`. Overflow is
reported through diagnostics rather than silently expanding queues forever. A
framework should surface diagnostics during development and choose capacities
that match its event-loop latency budget.

## Input, Text Input, And Focus

Input events carry an `InputEventTarget`. Pointer, keyboard, and touch payloads
can target a window surface, popup surface, display, focusless state, or an
unmanaged surface. `InputEvent.windowID` and `InputEvent.popup` are convenience
projections for routing.

Build the framework focus model above these facts:

- pointer focus changes come from pointer enter/leave events
- keyboard focus comes from keyboard enter/leave events
- text-input focus comes from `TextInputEvent.entered` and `.left`
- popups preserve popup identity and parent window identity

SwiftWayland preserves the target facts. The framework owns policy such as
"focused scene", tab focus, gesture capture, menu focus, and accessibility focus.

XDG activation tokens are opaque compositor-mediated focus facts. A framework
can request a token with app ID, window, seat ID, and serial hints, then send
`Window.activate(using:)`. It should not treat a sent activate request as a
guaranteed focus change.

For text fields, commit enabled request state before disabling the session.
`TextInputSession.disable()` finalizes the disable request; a later
`TextInputSession.commit()` is an invalid request and may produce a diagnostic.

## Rendering Loop

A framework-host render loop should be platform-shaped:

```swift
struct FrameworkWindowLoop {
    let window: Window

    func showInitialFrame(_ draw: @Sendable (borrowing SoftwareFrame) throws -> Void)
        async throws
    {
        try await window.show(draw)
    }

    func redrawIfNeeded(_ draw: @Sendable (borrowing SoftwareFrame) throws -> Void)
        async throws
    {
        guard try await !window.isClosed else { return }
        guard try await window.needsRedraw else { return }
        try await window.redraw(draw)
    }
}
```

Keep scene state, layout, widget invalidation, and renderer command generation
outside SwiftWayland. `Examples/FrameworkHostSmoke` includes an example-only
adapter. It is not public API yet because a real framework should prove the
shared shape first.

## Minimal Software Host Sketch

```swift
try await WaylandDisplay.withConnection { display in
    let window = try await display.createTopLevelWindow(
        configuration: WindowConfiguration(
            title: "App",
            appID: "app",
            initialWidth: 320,
            initialHeight: 240
        )
    )

    try await window.show { frame in
        frame.withXRGB8888Rows { _, pixels in
            for index in 0..<pixels.count {
                unsafe pixels[unchecked: index] = 0x0020_2020
            }
        }
    }

    var events = display.events.makeAsyncIterator()
    while let event = try await events.next() {
        switch event {
        case .redrawRequested(window.id):
            try await window.redraw { frame in
                frame.withXRGB8888Rows { _, pixels in
                    for index in 0..<pixels.count {
                        unsafe pixels[unchecked: index] = 0x0040_3030
                    }
                }
            }
        case .windowCloseRequested(window.id):
            await window.close()
        case .windowClosed(window.id):
            return
        default:
            break
        }
    }
}
```

## Minimal Graphics Preview Sketch

```swift
import WaylandClient
import WaylandGraphicsPreview

try await WaylandDisplay.withConnection { display in
    let backing = try await display.createGraphicsWindowBacking(
        windowConfiguration: WindowConfiguration(
            title: "Preview",
            appID: "preview",
            initialWidth: 320,
            initialHeight: 240
        ),
        graphicsConfiguration: WaylandGraphicsConfiguration(
            fallbackPolicy: .forceSoftware,
            presentationFeedbackPolicy: .requestWhenAvailable
        )
    )

    let lease = try await backing.nextFrame()
    let result = try await lease.submitSoftware { frame in
        frame.withXRGB8888Rows { _, pixels in
            for index in 0..<pixels.count {
                unsafe pixels[unchecked: index] = 0x0030_4050
            }
        }
    }

    _ = result.runtimePath
    try await backing.close()
}
```

`WaylandGraphicsPreview` is preview API. It reports runtime path and fallback
facts and currently provides managed software submission. It does not expose raw
Wayland, SHM pool, GBM, EGL, DRM, dmabuf, or sync handles.

## Boundaries SwiftWayland Does Not Own

A downstream framework owns:

- retained view trees and diffing
- layout and constraints
- widgets and controls
- gesture recognition
- app routing and command handling
- text editor behavior
- renderer scene graphs and shader models
- asset and theme policy
- accessibility semantics
- focus policy above protocol target facts
- damage calculation policy beyond the public damage values
- diagonal resize cursor fallback until portable cursor theme names are proven

SwiftWayland should continue exposing typed platform facts and narrow commit
operations, not framework policy.
