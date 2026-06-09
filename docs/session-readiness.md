# Session Readiness

SwiftWayland should give a future GUI framework enough platform facts to build
local app and window restoration without making SwiftWayland own app session
policy. This document describes that boundary.

SwiftWayland does not currently expose a public compositor session-management
protocol API. The protocol is tracked as deferred because its upstream phase,
compositor coverage, and framework-facing shape still need evidence. Frameworks
can still build useful local session restoration today with app-owned state and
public SwiftWayland facts.

## Ownership Boundary

SwiftWayland owns:

- app ID and title facts for managed toplevel windows
- stable public window identity through `WindowID`
- window lifecycle events and close requests
- current surface geometry, scale, output membership, and decoration mode facts
- activation token requests and activation requests through `xdg_activation_v1`
- typed capability reporting for optional compositor protocols
- future compositor session-management protocol plumbing, when it is ready

Frameworks own:

- scene identity
- document identity
- state encoding and migration
- restart and reopen policy
- unsaved-document prompts
- user-facing restore and shutdown UI
- where framework-specific state is stored below the app state root

SwiftWayland should not decide what a document, scene, tab, navigation path, or
saved editor state means. It should preserve enough platform state for a
framework to make those decisions.

## App-Owned State Location

Use `XDG_STATE_HOME` for user-specific state that should persist across
application restarts but is not portable user data. If `XDG_STATE_HOME` is unset
or empty, use `$HOME/.local/state`. The XDG Base Directory specification defines
this state directory for persistent local state such as view and layout state,
logs, history, and similar restart facts:
<https://specifications.freedesktop.org/basedir-spec/0.8/>

A framework can store state under a stable app directory such as:

```text
$XDG_STATE_HOME/org.example.App/session.json
```

SwiftWayland examples use an override for tests and smoke runs. Real frameworks
should let apps choose their own state schema and migration policy.

## Public Facts To Persist

Use ``Window/restorationSnapshot`` after the window has received its initial
configure. The snapshot is a platform-fact bundle, not a command to restore the
window exactly.

Useful facts:

- ``WindowRestorationSnapshot/windowID`` for routing within the current process
- ``WindowRestorationSnapshot/title`` for app-owned title restoration
- ``WindowRestorationSnapshot/appID`` for desktop identity
- ``WindowRestorationSnapshot/geometry`` for logical size, buffer size, and
  scale facts
- ``WindowRestorationSnapshot/state`` for configure serial, toplevel states,
  bounds, manager capabilities, decoration mode, and output membership
- ``WindowRestorationSnapshot/decorationMode`` for the current decoration fact
- ``WindowRestorationSnapshot/outputs`` for output membership at capture time

Do not treat `WindowID` as a cross-process persistent scene ID. It identifies a
managed window in the current display connection. A framework should persist its
own scene or document key and associate it with a new SwiftWayland window on the
next launch.

## Restore Flow

A framework-owned restore flow can be:

1. Read the app session file from `XDG_STATE_HOME`.
2. Decode framework scene and document state.
3. Open `WaylandDisplay.withConnection`.
4. Create windows with saved app ID, title, and approximate size through
   ``WindowConfiguration``.
5. Present an initial frame with ``Window/show(timeoutMilliseconds:_:)``.
6. Capture fresh ``Window/restorationSnapshot`` values after configure.
7. Route input, redraw, close, and output-change events with public IDs.
8. Save updated framework state during normal shutdown or after significant
   scene changes.

The compositor may ignore exact placement, size, activation, and decoration
preferences. Store them as useful hints rather than guarantees.

## Activation Is Not Restoration

Activation tokens are compositor-mediated focus or raise requests. They are not
restore tokens and should not be used as app session identifiers.

Use ``Window/requestActivationToken(appID:serialContext:timeoutMilliseconds:)``
when the framework has a reason to request focus for a restored or newly opened
window. Use the framework session key to restore app state. Keep those identities
separate.

## Protocol Watch

SwiftWayland tracks compositor session-management protocol support as future
work. The public API should remain deferred until the project has:

- protocol XML vendored and generated
- upstream phase and naming understood
- compositor advertisement evidence in `docs/compositor-matrix.md`
- at least one smoke or example path proving lifecycle behavior
- a framework usage shape that does not confuse local scene restoration with
  compositor session protocol events

The protocol status should be recorded as evidence, not assumed from the
presence of generated wrappers.
