# Session Readiness

Use WaylandClientKit for platform facts that a framework can use to build local app
and window restoration. Keep scene, document, and UI policy above WaylandClientKit.

WaylandClientKit currently exposes restoration-relevant facts through
``Window/restorationSnapshot``. It does not expose public compositor
session-management protocol API.

## When To Use This

Use a restoration snapshot when a framework wants to save enough platform state
to recreate windows on a later launch:

- current window title
- app ID
- logical size, buffer size, and scale
- decoration mode
- output membership
- toplevel state and manager capability facts

Do not use the snapshot as a cross-process window identity. ``WindowID`` is a
managed-window identity for the current display connection.

## Capability Gates

Local restoration state does not require a compositor session-management
protocol. It does depend on normal window lifecycle:

- create a toplevel through ``WaylandDisplay/createTopLevelWindow(configuration:)``
- wait for the initial configure by calling ``Window/show(timeoutMilliseconds:_:)``
- capture ``Window/restorationSnapshot`` after configure

Activation is optional and capability-gated by
``WaylandCapabilities/xdgActivation``. Activation tokens can help request focus
for a restored window, but they are not restore tokens.

## Public APIs

```swift
let window = try await display.createTopLevelWindow(
    configuration: WindowConfiguration(
        title: "Document",
        appID: "org.example.App",
        initialWidth: 800,
        initialHeight: 600
    )
)

try await window.show { frame in
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            unsafe pixels[unchecked: index] = 0x0020_2020
        }
    }
}

let snapshot = try await window.restorationSnapshot
print(snapshot.title ?? "")
print(snapshot.geometry.logicalSize)
```

Persist framework-owned state under `XDG_STATE_HOME` or the platform state root
your app chooses. Ignore relative `XDG_STATE_HOME` values and fall back to the
platform state root, because XDG base-directory environment paths must be
absolute. WaylandClientKit does not encode scene or document state.

## Expected Errors

Capturing a restoration snapshot before the initial configure produces the same
typed map-before-configure error as ``Window/stateSnapshot``. Capturing after a
window or display is closed produces the normal closed or stale-handle errors.
Activation requests can fail when `xdg_activation_v1` is unavailable, the token
request times out, or compositor policy rejects the focus transfer.

## Framework Policy

WaylandClientKit owns:

- public window identity facts
- lifecycle and close events
- geometry, scale, outputs, decoration mode, and activation hooks

The framework owns:

- scene IDs
- document IDs
- save prompts
- state encoding and migration
- reopen policy
- exact UI shown during restore or shutdown

See [Session Readiness](../../../docs/session-readiness.md) and
[SessionStateSmoke](../../../Examples/SessionStateSmoke/main.swift) for a
runnable app-owned state example.
