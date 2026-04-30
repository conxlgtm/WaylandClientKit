# Architecture

## Layer Order

```text
Application code
    |
    v
WaylandClient
    -> WaylandRaw -> CWaylandProtocols -> CWaylandClientSystem
    -> WaylandRawUnsafeShim -> CWaylandUnsafeShim
    -> WaylandKeyboardInterpretation -> WaylandRaw
    -> WaylandCursor -> WaylandRaw

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
`WaylandRawUnsafeShim` holds the owner-thread executor and its Linux wake primitive.
The queue-specific Wayland prepare/read/cancel state machine lives in `WaylandRaw`
as `QueueEventLoopEngine`; unsafe/default-queue and executor integrations adapt to
that one engine instead of owning duplicate protocol loops.

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
- queue-specific event-loop pumping through `QueueEventLoopEngine`
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

### `WaylandRawUnsafeShim`

Purpose:

- owner-thread executor machinery that cannot be expressed as ordinary safe Swift yet

Intended contents:

- pthread owner-thread lifecycle
- eventfd wakeup integration
- owned `ExecutorJob` storage and exactly-once execution checks
- synchronous package bootstrap handoff for low-level tests only

Does not contain:

- Wayland proxy wrappers
- listener trampoline state
- public client APIs

### `CWaylandUnsafeShim`

Purpose:

- tiny C boundary for Linux primitives used by `WaylandRawUnsafeShim`

Contains:

- eventfd creation and flag accessors

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

- `WaylandDisplay` actor for the high-level async API, backed by a dedicated
  `WaylandThreadExecutor`
- actor-owned windows addressed by `WindowID`, so public handles do not destroy Wayland
  proxies from arbitrary threads
- software-buffer toplevel window helper
- package-visible window lifecycle and redraw scheduling helpers
- span-scoped XRGB8888 drawing API
- frame callback based redraw pacing
- lifecycle state for configure, map, redraw, and close handling
- package-internal `DisplaySession` as the owner of manual pumping, window creation,
  input side effects, and input draining
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

`DisplaySession.pumpEvents(timeoutMilliseconds:)` pumps Wayland callbacks and immediately
processes raw input side effects such as cursor state and keyboard interpretation. Public
session-level input events are buffered until `DisplaySession.drainInputEvents()` is called.
Public events carry sequence, seat identity, optional window identity, raw pointer/keyboard/touch facts, and interpreted keyboard facts.

`KeyboardEvent.raw` carries protocol facts. The raw keycode is the Wayland/evdev keycode, not text.
`KeyboardEvent.interpreted` carries xkbcommon key symbols and simple UTF-8 values when a copied
`xkb_v1` keymap is available.

UTF-8 values from key events are key interpretation output. They are not committed text input.

Pointer coordinates are surface-local.

Pointer cursor images are session policy. `WaylandClient` resolves the desired `PointerCursor`
through `WaylandCursor`, creates per-seat cursor surfaces, attaches cursor theme buffers whose
theme lifetime is retained by the image wrapper, and calls `wl_pointer.set_cursor` with the
pointer enter serial for registered client surfaces.

## Runtime Model

The low-level/manual-loop API is single-thread-affine. Create, pump, use, and destroy
Wayland objects from one thread unless a later story explicitly introduces event-queue
ownership for more threads. Public thread-affine calls are unavailable from async contexts
so Swift tasks do not accidentally resume on a different executor/thread while holding
Wayland ownership.

The high-level async API is `WaylandDisplay`, an actor with a dedicated
`WaylandThreadExecutor`. The actor strongly retains its executor and returns the same
`UnownedSerialExecutor` for its lifetime. Actor-isolated methods run on the Wayland owner
thread. The executor thread owns the high-level loop; `events` and `inputEvents` are passive
subscribers and do not own pumping.

The executor loop drains a bounded batch of Swift jobs, then runs one Wayland event-source
turn when a display source is registered. That turn uses the canonical Wayland prepare-read
sequence and polls both the Wayland display fd and the executor wake fd. Work enqueued while
the loop is polling wakes the poll, causes the prepared read to be completed or canceled, and
then runs in the next executor job phase. No arbitrary Swift jobs run between a successful
prepare-read and read-events/cancel-read.

Display streams are bounded throwing streams. Normal `WaylandDisplay.close()` finishes them
without error; fatal Wayland/protocol/poll failures finish subscribers with
`WaylandDisplayError`; subscriber overflow terminates only the slow subscriber rather than
backpressuring the owner thread.

Nonterminal runtime degradation is reported as diagnostics. Display subscribers receive
`DisplayEvent.diagnostic`, while input subscribers still receive input-specific diagnostic
events through `inputEvents`. This keeps fatal display failure, subscriber-local overflow,
and recoverable input/cursor degradation separate.

`WaylandDisplay` requires explicit `close()`. Window teardown is routed through the display
actor. `Window` is a lightweight public handle, and `TopLevelWindow` remains an actor-owned
implementation detail for the async API.

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
- `Sources/CWaylandUnsafeShim/`

Swift code:

- `Sources/WaylandRaw/`
- `Sources/WaylandRawUnsafeShim/`
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
- `make strict-memory-safety-raw`
- `make test`
- `make check`

`WaylandClient` builds with strict memory safety as errors. `WaylandRaw` and
`WaylandRawUnsafeShim` are still being audited because they own intentional C, pointer, and
executor boundaries. `make strict-memory-safety-raw` builds both targets with strict
memory-safety diagnostics enabled and compares warnings against a per-file baseline. The
baseline should only move down as raw wrappers are converted to small audited unsafe shims,
noncopyable ownership tokens, and scoped borrowed views.
