# Architecture

## Layer Order

```text
Application code
    |
    v
WaylandClient
    |\
    | \
    |  v
    |  WaylandKeyboardInterpretation
    |      |
    v      v
WaylandRaw
    |
    v
CWaylandProtocols
    |
    v
CWaylandClientSystem

WaylandClient also depends on WaylandCursor.
WaylandCursor depends on WaylandRaw and CWaylandCursorShims.
CWaylandCursorShims depends on CWaylandCursorSystem.
WaylandKeyboardInterpretation also depends on CXKBCommonSystem.

SwiftWaylandSmoke
    executable consumer of WaylandClient through WaylandSmokeSupport
```

`WaylandClient` uses `WaylandKeyboardInterpretation` to expose interpreted keyboard events in the session input stream.
`WaylandClient` uses `WaylandCursor` to resolve cursor theme images and set cursor surfaces on pointer focus.
`WaylandRaw` does not depend on xkbcommon.
`WaylandRaw` does not depend on wayland-cursor.

## Target Roles

### `CWaylandClientSystem`

Purpose:

- import installed Wayland client headers into SwiftPM

Contains:

- `module.modulemap`
- umbrella header for system headers

Does not contain:

- generated protocol files
- shim implementations
- project-specific runtime logic

### `CXKBCommonSystem`

Purpose:

- import installed xkbcommon headers into SwiftPM

Contains:

- `module.modulemap`
- umbrella header for xkbcommon headers

Does not contain:

- keyboard policy
- key symbol or text interpretation logic

### `CWaylandCursorSystem`

Purpose:

- import installed wayland-cursor headers into SwiftPM

Contains:

- `module.modulemap`
- umbrella header for wayland-cursor headers

Does not contain:

- cursor policy
- Swift ownership logic

### `CWaylandCursorShims`

Purpose:

- expose the small wayland-cursor ABI surface Swift needs

Contains:

- cursor theme load/destroy wrappers
- cursor lookup wrappers
- cursor image metadata accessors
- cursor image buffer lookup

Does not contain:

- `wl_pointer.set_cursor`
- window or session policy

### `CWaylandProtocols`

Purpose:

- hold project-owned C interop files

Contains:

- generated protocol headers
- generated protocol C files
- shim header
- shim C files

Subdirectories:

- `include/generated/`
- `generated/`
- `shims/`

### `WaylandRaw`

Purpose:

- low-level Swift layer

Intended contents:

- proxy wrappers
- ownership rules
- version handling
- callback lifetime handling
- event-loop pumping
- registry and seat discovery
- shared-memory buffer management
- raw pointer, keyboard, and touch event capture
- raw pointer cursor request forwarding
- raw input `AsyncSequence` adapter
- copied keyboard keymap payloads

Does not depend on:

- `CXKBCommonSystem`
- xkbcommon interpretation APIs
- `CWaylandCursorSystem`
- wayland-cursor APIs

### `WaylandCursor`

Purpose:

- wrap installed cursor themes and static cursor images

Current state:

- imports wayland-cursor through `CWaylandCursorShims`
- loads a cursor theme for a `wl_shm`
- resolves named cursors to image metadata and borrowed cursor buffers
- keeps cursor image buffers owned by the cursor theme
- does not know about windows, seats, or input routing

### `WaylandKeyboardInterpretation`

Purpose:

- provide xkbcommon-backed interpretation for copied raw keyboard facts

Current state:

- imports xkbcommon through `CXKBCommonSystem`
- parses copied `xkb_v1` keymap payloads from `WaylandRaw`
- owns xkb context, keymap, and state lifetimes inside thread-affine Swift objects
- applies Wayland modifier masks
- exposes interpreted key symbols and UTF-8 text for raw key events
- does not expose shortcut policy, compose behavior, text-input protocols, or IME behavior

### `WaylandClient`

Purpose:

- public Swift layer

Current state:

- software-buffer toplevel window helper
- span-scoped XRGB8888 drawing API
- frame callback based redraw pacing
- lifecycle state for configure, map, redraw, and close handling
- `DisplaySession` as the owner of event pumping, window creation, and input draining
- `InputRouter` that maps raw input events to public session input events
- session-owned `KeyboardInterpreter` that maps raw keyboard facts to public interpreted keyboard events
- session-owned `CursorManager` that sets cursor surfaces when pointer focus enters registered windows

### `WaylandSmokeSupport`

Purpose:

- shared smoke-test command parsing and runtime logic

Current state:

- builds a tiny window through `DisplaySession`
- commits one SHM frame
- exits without requiring pointer or keyboard input

### `SwiftWaylandSmoke`

Purpose:

- noninteractive executable for manual and CI Wayland smoke checks

## Input Model

Input starts at `wl_seat`.

`WaylandRaw` binds every usable advertised seat, tracks advertised and active capabilities separately, and owns child `wl_pointer`, `wl_keyboard`, and `wl_touch` lifetimes.

Raw input events carry:

- sequence number
- seat identity
- optional generation-aware child device identity
- protocol serials and raw values

`WaylandClient` exposes session-level input events through `DisplaySession.drainInputEvents()`.
Public events carry sequence, seat identity, optional window identity, raw pointer/keyboard/touch facts, and interpreted keyboard facts.

`KeyboardEvent.raw` carries protocol facts. The raw keycode is the Wayland/evdev keycode, not text.
`KeyboardEvent.interpreted` carries xkbcommon key symbols and simple UTF-8 values when a copied
`xkb_v1` keymap is available.

UTF-8 values from key events are key interpretation output. They are not committed text input.

Pointer coordinates are surface-local.

Pointer cursor images are session policy. `WaylandClient` resolves the desired `PointerCursor`
through `WaylandCursor`, creates per-seat cursor surfaces, attaches borrowed cursor theme buffers,
and calls `wl_pointer.set_cursor` with the pointer enter serial for registered client surfaces.

## Runtime Model

The experimental baseline is single-thread-affine. Create, pump, use, and destroy Wayland objects from one thread unless a later story explicitly introduces event-queue ownership for more threads.

Public input events preserve seat identity and optional window identity. Keyboard events are not text input.

## Experimental Support Matrix

Supported:

- core Wayland display, registry, compositor, surface, callback, SHM, pool, buffer, seat, pointer, keyboard, and touch basics
- stable xdg-shell wm_base, surface, and toplevel basics
- basic `xkb_v1` keyboard interpretation through xkbcommon
- session-level raw and interpreted keyboard events
- static pointer cursor surfaces through wayland-cursor

Not supported:

- cursor animation or per-output cursor scaling
- xdg-decoration
- clipboard, primary selection, drag and drop
- text input or IME
- fractional-scale, viewporter, presentation-time
- EGL, GBM, dmabuf, or GPU rendering
- widgets or retained UI

## Source Categories

Repository-owned protocol inputs:

- `Protocols/`

Generated outputs:

- `Sources/CWaylandProtocols/include/generated/`
- `Sources/CWaylandProtocols/generated/`

Shim files:

- `Sources/CWaylandProtocols/include/swift-wayland-shims.h`
- `Sources/CWaylandProtocols/shims/`

Swift code:

- `Sources/WaylandRaw/`
- `Sources/WaylandClient/`
- `Sources/WaylandKeyboardInterpretation/`
- `Sources/WaylandSmokeSupport/`
- `Sources/SwiftWaylandDemo/`
- `Sources/SwiftWaylandSmoke/`

## Current Checks

- `make lint`
- `make verify-generated`
- `make verify-shims`
- `make strict-concurrency`
- `make test`
- `make check`
