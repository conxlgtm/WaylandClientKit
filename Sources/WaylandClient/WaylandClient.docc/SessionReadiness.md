# Session Readiness

Use WaylandClientKit for platform facts that a framework can use to build local
app and window restoration.

WaylandClientKit currently exposes restoration-relevant facts through
``Window/restorationSnapshot`` and compositor session-management advertisement
through ``WaylandCapabilities/compositorSessionManagement``. It does not expose
a transient session object or event snapshot because replacement can occur after
initial discovery.

A restoration snapshot contains platform state useful for recreating a window:

- current window title
- app ID
- logical size, buffer size, and scale
- decoration mode
- output membership
- toplevel state and manager capability facts

``WindowID`` is connection-local, not a cross-process window identity.

## Capability Gates

Local restoration state does not require a compositor session-management
protocol. It does depend on normal window lifecycle:

- create a toplevel through ``WaylandDisplay/createTopLevelWindow(configuration:)``
- wait for the initial configure by calling ``Window/show(timeoutMilliseconds:_:)``
- capture ``Window/restorationSnapshot`` after configure

Activation is optional and capability-gated by
``WaylandCapabilities/xdgActivation``.
Activation tokens are compositor-mediated focus or raise requests, not restore
tokens or session identifiers.

Compositor session management is optional and capability-gated by
``WaylandCapabilities/compositorSessionManagement``. The capability is an
advertisement fact, not a usable session handle. Local app restoration remains
framework-owned.

Persist framework-owned state under `XDG_STATE_HOME` or the platform state root
chosen by the app. Relative `XDG_STATE_HOME` values are invalid and fall back to
the platform state root. WaylandClientKit does not encode scene or document
state.

Snapshots requested before initial configure, or after closure, produce the
corresponding typed lifecycle error. Activation can also be unavailable, time
out, or be rejected by compositor policy.

WaylandClientKit owns window facts and lifecycle events. Frameworks own scene
and document identity, persistence, migration, reopen policy, and restore UI.

See [SessionStateSmoke](../../../Examples/SessionStateSmoke/main.swift) for a
runnable app-owned state example.
