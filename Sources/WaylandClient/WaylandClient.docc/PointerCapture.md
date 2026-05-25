# Pointer Capture

SwiftWayland exposes relative pointer and pointer-constraint protocols as typed
input substrate. Applications can subscribe to relative motion for a seat and
request compositor-mediated lock or confine constraints for a managed window.

Check ``WaylandCapabilities/relativePointer`` and
``WaylandCapabilities/pointerConstraints`` before offering capture-dependent UI.
If a compositor does not advertise a protocol, the request fails with
`PointerCaptureError.unavailable`.

Relative motion events arrive through ``InputEvents`` as
`PointerEvent.relativeMotion`. Constraint lifecycle events arrive through
`PointerEvent.constraint` and keep their locked or confined identity.

Pointer capture is still application policy. SwiftWayland does not decide when a
game mode starts, how the user exits pointer lock, what cursor is shown, or how
motion maps to a camera or gesture. It exposes the protocol facts and manages
proxy lifetime for windows, seats, and display shutdown.

```swift
let subscription = try await window.relativePointer(seatID: event.seatID)
let constraint = try await window.lockPointer(
    seatID: event.seatID,
    lifetime: .persistent
)

try await subscription.destroy()
try await constraint.destroy()
```
