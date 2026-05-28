# Activation And Focus Handoff

Use XDG activation when an app needs compositor-mediated focus transfer, such
as raising a managed window after app launch or an external command.

Activation is optional and policy-controlled by the compositor. Check
``WaylandCapabilities/xdgActivation`` first, but still handle unavailable
activation errors at request time because globals can disappear.

Request tokens through ``WaylandDisplay/requestActivationToken(_:timeoutMilliseconds:)``
or ``Window/requestActivationToken(appID:serialContext:timeoutMilliseconds:)``.
The returned ``ActivationToken`` is opaque. Do not parse it, store unrelated
app state in it, or treat receipt as proof that a future activate request will
focus a window.

When activation follows a user action, pass the same ``SeatID`` and
``InputSerial`` from that input event:

```swift
let token = try await window.requestActivationToken(
    appID: "org.example.App",
    serialContext: ActivationSerialContext(
        seatID: event.seatID,
        serial: button.serial
    )
)
try await window.activate(using: token)
```

SwiftWayland validates that activation requests target managed windows on the
owning display and keeps raw `xdg_activation_v1` proxies out of public API.
Frameworks remain responsible for app launch, command routing, and any visible
focus or attention policy.
