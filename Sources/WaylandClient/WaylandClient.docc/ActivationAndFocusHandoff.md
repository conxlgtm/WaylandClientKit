# Activation And Focus Handoff

Use XDG activation when an app needs compositor-mediated focus transfer, such
as raising a managed window after app launch or an external command.

Activation is optional and policy-controlled by the compositor. Check
``WaylandCapabilities/xdgActivation`` first, but still handle unavailable
activation errors at request time because a startup global can disappear.

Request tokens through ``WaylandDisplay/requestActivationToken(_:timeoutMilliseconds:)``
or ``Window/requestActivationToken(appID:serialContext:timeoutMilliseconds:)``.
The returned ``ActivationToken`` is only for activation requests. It is not an
app-state container or a guarantee that the compositor will focus a window.

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

WaylandClientKit validates target ownership. Frameworks remain responsible for
app launch, command routing, and visible focus or attention policy.
