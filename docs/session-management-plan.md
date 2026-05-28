# Session Management Plan

SwiftWayland should expose protocol facts that a higher app framework needs for
session restore, shutdown prompts, and app/window identity. It should not own
document lifecycle, autosave policy, scene restoration, or user-facing prompts.

## Upstream Status

The local `wayland-protocols` install used for this pass contains
`ext-session-lock-v1`, but not an XDG session-management protocol XML. Roadmap
notes from newer protocol discussions mention XDG Session Management as an
emerging desktop-integration area, so SwiftWayland should treat it as
experimental until the protocol XML and phase are confirmed in the vendored
manifest.

No public session-management API should land before the protocol is vendored,
manifest-tracked, generated, and described in the compositor matrix.

## App And Window Identity

SwiftWayland already accepts window title and app ID through
`WindowConfiguration`. A session-management API will likely need these facts:

- stable application ID
- stable window role or restoration key supplied by the app framework
- current toplevel identity
- startup/activation token context when a restored or launched app is raised
- output and scale facts for best-effort placement hints

SwiftWayland can preserve and report these facts, but the framework owns their
meaning. For example, SwiftWayland should not decide whether two windows are the
same document, whether a restoration key is valid, or whether unsaved work can
be discarded.

## Restore Tokens

Future restore-token support should be explicit and typed:

- tokens are opaque values
- token creation and consumption can fail with typed unavailable or rejected
  errors
- tokens should carry no SwiftWayland-owned document state
- token lifetimes should follow protocol rules and be invalidated when the
  compositor reports expiry or session end

If a protocol requires user-initiated serials, the request shape should preserve
`SeatID`, input serial, and requesting `WindowID`, matching the existing
serial-sensitive interaction guidance.

## Shutdown And Save Prompts

Shutdown/save decisions belong above SwiftWayland. A future API can surface
events such as "session save requested" or "shutdown requested" if the protocol
has those concepts, but the app framework must decide:

- whether a document has unsaved changes
- whether to block shutdown
- what prompt to show
- when save has completed
- how session state is serialized

SwiftWayland should provide the protocol request/response plumbing and clear
timeout/error behavior. It should not own prompt UI or autosave policy.

## Relationship To Activation

`xdg_activation_v1` is the first desktop-integration API. It is
capability-reported through `WaylandCapabilities.xdgActivation`, has public
opaque `ActivationToken` request and activate calls, and has a live smoke that
prints capability, token, and activate-request behavior. Activation tokens and
session restore tokens should stay separate types even if an app framework uses
both during app launch and focus transfer.

## Compatibility Risk

Session-management protocol shape may change while upstream is experimental.
SwiftWayland should use these gates before exposing public API:

- protocol phase recorded in `protocols/manifest.json`
- generated C artifacts checked in
- raw proxy wrappers own and destroy all child objects
- capability reporting exposes advertised and unavailable states
- live matrix rows show at least one compositor advertising the protocol, or
  docs explicitly say no compositor evidence exists yet
- public API baseline and audit are updated in the same change

If the protocol remains experimental, expose it as preview or capability-only
until multiple app-framework workflows prove the API shape.

## SwiftWayland Boundary

Belongs in SwiftWayland:

- vendored protocol XML, generated artifacts, and raw proxy lifetime wrappers
- typed capability reporting
- typed request/event values that preserve protocol identity
- bounded waits, diagnostics, and typed unavailable/rejected errors
- examples that print compositor support and protocol events

Belongs in a higher framework:

- document/session model
- restore-key naming
- save prompts and UI
- window placement policy
- app-command routing
- user-facing recovery behavior

SwiftWayland should expose enough facts for a framework to build those policies
without raw Wayland access.
