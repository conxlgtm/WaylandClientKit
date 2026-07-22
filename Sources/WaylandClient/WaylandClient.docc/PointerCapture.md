# Pointer Capture

WaylandClientKit exposes relative pointer, pointer-constraint, pointer-gesture, and pointer-warp
protocols as typed input substrate. Applications can subscribe to relative
motion for a seat, request compositor-mediated lock or confine constraints for a
managed window, subscribe to touchpad gesture facts for a seat, and request a
serial-scoped pointer warp within a managed window.

Check ``WaylandCapabilities/relativePointer`` and
``WaylandCapabilities/pointerConstraints`` before offering capture-dependent UI.
Check ``WaylandCapabilities/pointerWarp`` before offering direct pointer-position
controls. If a compositor does not advertise a protocol, the request fails with
`PointerCaptureError.unavailable` or `PointerWarpError.unavailable`.
Check ``WaylandCapabilities/pointerGestures`` before subscribing to touchpad
gesture facts.

Relative motion events arrive through ``InputEvents`` as
`PointerEvent.relativeMotion`. Constraint lifecycle transitions arrive through
`PointerEvent.constraintLifecycle`. `defunctOneShot` means the protocol object
has been destroyed. `inactivePersistent` remains valid and may become active
again.
Gesture events arrive through ``InputEvents`` as `PointerEvent.gesture`. Swipe,
pinch, and hold payloads preserve protocol serials, event times, finger counts,
deltas, scale, rotation, and cancellation state.

Applications decide when capture starts, how users leave it, which cursor is
shown, and how motion maps to app behavior.

Pointer warp is also compositor policy. The request requires an input serial and
is scoped to the caller's managed window, seat pointer, and logical surface
position. A successful request means the protocol request was sent. It does not
guarantee the compositor will visibly move the pointer.

```swift
let subscription = try await window.relativePointer(seatID: event.seatID)
let gestures = try await display.pointerGestures(seatID: event.seatID)
let constraint = try await window.lockPointer(
    seatID: event.seatID,
    lifetime: .persistent
)

try await subscription.destroy()
try await gestures.destroy()
try await constraint.destroy()

try await window.requestPointerWarp(
    seatID: event.seatID,
    position: LogicalOffset(x: 32, y: 32),
    serial: eventSerial
)
```

## Example

See `PointerCaptureSmoke` in `Examples/PointerCaptureSmoke` and
`PointerGesturesSmoke` in `Examples/PointerGesturesSmoke`.
