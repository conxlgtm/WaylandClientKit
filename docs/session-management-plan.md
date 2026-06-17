# Compositor Session Management Plan

WaylandClientKit tracks compositor session-management support through the
upstream staging protocol `xdg-session-management-v1`.

## Protocol Decision

- XML name: `xdg-session-management-v1.xml`
- Primary global: `xdg_session_manager_v1`
- Upstream phase: staging
- Vendored source: wayland-protocols 1.48 staging
- Current product tier: preview foundation

The protocol is vendored and generated, raw wrappers exist, and the public
preview API exposes capability-gated event snapshots through
`WaylandDisplay.compositorSessionEvents(reason:existingID:)`.

## Boundary

WaylandClientKit can expose compositor facts and protocol-shaped requests. It
does not own framework scene identity, document identity, restore schemas,
state migration, or user-facing save/restore policy.

Local framework restoration remains based on app-owned state plus
`WindowRestorationSnapshot`. `SessionStateSmoke` remains the runnable local
restoration example.

## Public Preview API

The current public API is deliberately narrow:

- capability reporting through `WaylandCapabilities.compositorSessionManagement`
- `CompositorSessionID` as compositor protocol identity, not scene/document ID
- `CompositorSessionReason` for protocol-shaped launch/session reasons
- `CompositorSessionEvent` for created/restored/replaced facts
- `CompositorSessionSmoke`, which skips cleanly when unavailable

A broader compositor session API needs more evidence before release:

- live compositor advertisement rows in `docs/compositor-matrix.md`
- lifecycle smoke output for created/restored/replaced events
- clear behavior across display close, window close, and late compositor events
- a framework usage shape that keeps compositor session identities separate
  from local scene/document keys

Until those are proven, local app/window restoration remains the job of
`SessionStateSmoke` and framework-owned state.

## Text Input 1.48 Refresh

The bundled `text-input-v3` XML is the v2 protocol shape. Public text-input
support includes preedit hints, language events, on-screen input content hints,
and version-gated input-panel show/hide hints. `disable()` still finalizes the
disable request and should not be followed by `commit()`.
