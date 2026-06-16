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
`PointerEvent.constraintLifecycle`. One-shot terminal transitions are reported
as `PointerConstraintLifecycleEvent.defunctOneShot`, which means WaylandClientKit
has already destroyed the protocol object and callers do not need to destroy
the handle. Persistent terminal transitions are reported as
`PointerConstraintLifecycleEvent.inactivePersistent`, which means the protocol
object remains valid and may later become active again.
Gesture events arrive through ``InputEvents`` as `PointerEvent.gesture`. Swipe,
pinch, and hold payloads preserve protocol serials, event times, finger counts,
deltas, scale, rotation, and cancellation state. WaylandClientKit does not turn
these facts into higher-level swipe, magnification, rotation, or scroll policy.

Pointer capture is still application policy. WaylandClientKit does not decide when a
game mode starts, how the user exits pointer lock, what cursor is shown, or how
motion maps to a camera or gesture. It exposes the protocol facts and manages
proxy lifetime for windows, seats, and display shutdown.

Pointer warp is also compositor policy. The request requires an input serial and
is scoped to the caller's managed window, seat pointer, and logical surface
position. A successful request means the protocol request was sent; it does not
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

## Public APIs

- ``Window/relativePointer(seatID:)``
- ``Window/lockPointer(seatID:cursorHint:region:lifetime:)``
- ``Window/confinePointer(seatID:region:lifetime:)``
- ``Window/requestPointerWarp(seatID:position:serial:)``
- ``WaylandDisplay/pointerGestures(seatID:)``
- ``RelativePointerSubscription``
- ``PointerGestureSubscription``
- ``PointerGestureEvent``
- ``PointerConstraint``
- ``PointerConstraintLifecycleEvent``
- ``PointerWarpError``

## Example

See `PointerCaptureSmoke` in `Examples/PointerCaptureSmoke` and
`PointerGesturesSmoke` in `Examples/PointerGesturesSmoke`.
